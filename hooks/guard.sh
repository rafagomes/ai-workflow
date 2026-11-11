#!/usr/bin/env bash
# wf guardrail hook: a PreToolUse hook on the Bash tool.
#
# Reads the hook JSON on stdin and blocks (exit 2, reason on stderr, which Claude
# Code feeds back to the model) a command that:
#   no-verify           runs `git commit` or `git push` with --no-verify (or `commit -n`)
#   trunk-force-push    force-pushes the trunk (main, master or the origin default branch)
#   trunk-delete        deletes the trunk on the remote
#   pr-approve          runs `gh pr review --approve` (approving is the human's call)
#   too-large           the command is over 128 KB, has over 500 git/gh segments, more
#                       than 100000 words after its git/gh words, over 256 refs in a
#                       push, or a cd or git -C path over 4 KB (too much to inspect)
#   too-slow            the analysis did not finish in 5 s (a hook timeout does not block,
#                       so the guard enforces its own deadline and fails closed)
#
# This is a guardrail against mistakes, not a security boundary. It does not
# parse shell. It reads the command as raw text: quotes, backslashes and
# backticks, ( ) { } become spaces, and the text is split into segments at newlines
# and ; & |. In every segment, EVERY word `git` (so `xargs git`, `timeout 5
# git`, `sudo -u u git`, `bash <<< "git commit -n"`, text inside $(...) or
# backticks) and every word `gh` is read as a command, and the rules apply to the
# words after it. Quoting cannot hide a command; it fails closed. Also read: a
# backslash-newline continues a line, redirections (`main>/dev/null`, `2>&1`)
# are dropped, `--` is not honoured, long options match as git abbreviates them
# (`--no-verif`, `--force-w`, `--delet`), the trunk may be written `heads/main`,
# `refs/heads/main` or `@`, and `git push --mirror` counts as a force-push.
#
# Known false positives: any text that literally contains a forbidden command is
# blocked, whatever it is wrapped in: a commit or PR body, an echo or grep
# string, single-quoted text, a heredoc. Workarounds: `git commit -F <file>`,
# `gh pr create|comment --body-file <file>`, or WF_GUARD=off for a deliberate
# session. Not covered: variables, aliases, git aliases, `git -c core.hooksPath`,
# scripts, `gh api`, and a command split by quotes inside a word (`g"i"t`).
#
# The analysis runs in a child under `timeout` (`gtimeout` on macOS, else a perl
# alarm); with none of them only the size caps bound the work (a push may name at
# most 256 refs, and git lookups are cached per push). WF_GUARD_TIMEOUT overrides the 5 s.
#
# Fails open: with neither jq nor python3, or JSON it cannot parse, the command is
# allowed and a one-line warning goes to stderr, so a missing tool never bricks a
# session. Escape hatch: WF_GUARD=off in the hook's own environment (set it in the
# settings `env`, not inline in the command) allows everything.

US=$'\037'   # separator between the words of a segment

deny() { # deny <rule> <message>
    printf 'wf guard [%s]: %s (WF_GUARD=off in settings env disables the guard)\n' "$1" "$2" >&2
    exit 2
}

warn_open() { echo "wf guard: $1; guardrails skipped for this command" >&2; exit 0; }

input=$(cat)   # always drain stdin, even when the guard is off
[ "${WF_GUARD:-}" = "off" ] && exit 0
[ ${#input} -le 1048576 ] || deny too-large "the hook input is over 1 MB, too big to inspect; split the command up"

# Deadline: run the analysis in a child under timeout (gtimeout on macOS, else a
# perl alarm), and block when it does not finish, because a hook that times out
# is not blocking. Without any of them only the size caps bound the work. Exits
# 0 or 2 only.
if [ -z "${WF_GUARD_INNER:-}" ]; then
    tmo=$(command -v timeout || command -v gtimeout) || tmo=""
    runner=()
    if [ -n "$tmo" ]; then
        runner=("$tmo" -k 1 "${WF_GUARD_TIMEOUT:-5}")
    elif command -v perl >/dev/null 2>&1; then
        runner=(perl -MTime::HiRes=alarm -e 'alarm shift; exec @ARGV' "${WF_GUARD_TIMEOUT:-5}")
    fi
    if [ ${#runner[@]} -gt 0 ]; then
        printf '%s' "$input" | WF_GUARD_INNER=1 "${runner[@]}" bash "${BASH_SOURCE[0]}"
        rc=$?
        case $rc in
            0|2) exit $rc ;;
            124|137|142|143) deny too-slow "the command took too long to inspect; split it up or write it to a script file" ;;
            *) warn_open "the guard failed (exit $rc)" ;;
        esac
    fi
fi
json_field() { # json_field <jq-path> <dotted-key>
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null
    else
        printf '%s' "$input" | python3 -I -c '
import sys, json
v = json.load(sys.stdin)
for k in sys.argv[1].split("."):
    v = v.get(k) if isinstance(v, dict) else None
sys.stdout.write(v if isinstance(v, str) else "")' "$2" 2>/dev/null
    fi
}
if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    warn_open "neither jq nor python3 found"
fi
tool=$(json_field .tool_name tool_name) || warn_open "could not parse hook input"
[ -n "$tool" ] && [ "$tool" != "Bash" ] && exit 0
command_str=$(json_field .tool_input.command tool_input.command) || warn_open "could not parse hook input"
[ -n "$command_str" ] || exit 0
WD=$(json_field .cwd cwd) || WD=""
[ -n "$WD" ] || WD="."

[ ${#command_str} -le 131072 ] || deny too-large "the command is over 128 KB, too big to inspect; split it up or write it to a script file"

git_dir() { git -C "$WD" "$@" 2>/dev/null; }

# Per check_push call caches, so a push costs a fixed number of git processes
# however many refs it names: the current branch, and the remotes' default branches.
CUR_INIT=0; CUR_VAL=""; TRUNK_INIT=0; TRUNK_EXTRA=""
cur_branch() {
    [ $CUR_INIT = 1 ] && return 0
    CUR_INIT=1
    CUR_VAL=$(git_dir symbolic-ref --short HEAD)
}

# is_trunk <branch> <remote>: main, master, or the remote's default branch.
is_trunk() {
    local b="$1" r="${2:-origin}" d rr x
    case "$b" in main|master) return 0 ;; esac
    [ -n "$b" ] || return 1
    if [ $TRUNK_INIT = 0 ]; then
        TRUNK_INIT=1
        for rr in "$r" origin; do
            d=$(git_dir symbolic-ref --short "refs/remotes/$rr/HEAD") || continue
            TRUNK_EXTRA="$TRUNK_EXTRA ${d#"$rr"/}"
        done
    fi
    for x in $TRUNK_EXTRA; do [ "$x" = "$b" ] && return 0; done
    return 1
}

# is_opt <word> <long option without --> <min length>: the word is that long option
# or an abbreviation of it (git accepts unambiguous prefixes), with or without =value.
is_opt() {
    [ ${#1} -le 64 ] || return 1   # no long option is that long; the expansions are quadratic on huge words
    local w="${1#--}"
    w="${w%%=*}"
    [ ${#w} -ge "$3" ] && [ ${#w} -le ${#2} ] && [[ "$2" == "$w"* ]]
}

check_commit_push() { # check_commit_push <sub> <args...>
    local sub="$1" a cluster ch i skip=0
    shift
    for a in "$@"; do
        if [ $skip = 1 ]; then skip=0; continue; fi
        case "$a" in
            --message|--file|--reuse-message|--reedit-message|--fixup|--squash|--author|--date|--template|--cleanup)
                skip=1 ;;
            --*)
                if is_opt "$a" no-verify 4; then
                    deny no-verify "git $sub --no-verify skips the repo's hooks; fix what the hook reports and run it without --no-verify"
                fi ;;
            -?*)
                [ "$sub" = commit ] || continue
                cluster="${a#-}"; cluster="${cluster:0:32}"
                for ((i = 0; i < ${#cluster}; i++)); do
                    ch="${cluster:i:1}"
                    case "$ch" in
                        n) deny no-verify "git commit -n is --no-verify and skips the repo's hooks; fix what the hook reports and run it without -n" ;;
                        m|F|C|c|t) [ $((i + 1)) -eq ${#cluster} ] && skip=1; break ;;
                    esac
                done ;;
        esac
    done
}

check_push() { # check_push <args...>
    local a cluster ch i skip=0 force=0 del=0 all=0 remote="" have_remote=0 ref dst forced cur
    local refs=()
    CUR_INIT=0; TRUNK_INIT=0; TRUNK_EXTRA=""
    for a in "$@"; do
        if [ $skip = 1 ]; then skip=0; continue; fi
        if [[ "$a" == -* ]] && [ "$a" != "-" ]; then
            case "$a" in
                --) ;;
                --repo|--receive-pack|--exec|--push-option|--signed) skip=1 ;;
                --*)
                    # git accepts unambiguous abbreviations of long options
                    if is_opt "$a" force-with-lease 3 || is_opt "$a" force-if-includes 3; then force=1; fi
                    if is_opt "$a" delete 2; then del=1; fi
                    if is_opt "$a" all 2; then all=1; fi
                    if is_opt "$a" mirror 1; then force=1; all=1; fi ;;
                *)
                    cluster="${a#-}"; cluster="${cluster:0:32}"
                    for ((i = 0; i < ${#cluster}; i++)); do
                        ch="${cluster:i:1}"
                        case "$ch" in
                            f) force=1 ;;
                            d) del=1 ;;
                            o) [ $((i + 1)) -eq ${#cluster} ] && skip=1; break ;;
                        esac
                    done ;;
            esac
        elif [ $have_remote = 0 ]; then
            remote="$a"; have_remote=1
        else
            refs+=("$a")
        fi
    done

    [ ${#refs[@]} -le 256 ] || deny too-large "more than 256 refs in one push, too many to inspect; push fewer refs"
    for ref in ${refs[@]+"${refs[@]}"}; do
        [ ${#ref} -le 1024 ] || continue   # no ref name is that long; the expansions below are quadratic on long words
        forced=$force
        [[ "$ref" == +* ]] && { forced=1; ref="${ref#+}"; }
        if [[ "$ref" == *:* ]]; then
            dst="${ref#*:}"
            [ -z "${ref%%:*}" ] && del=1
        else
            dst="$ref"
        fi
        dst="${dst#refs/}"; dst="${dst#heads/}"
        if [ "$dst" = HEAD ] || [ "$dst" = "@" ]; then cur_branch; dst="$CUR_VAL"; fi
        if [ $del = 1 ] && is_trunk "$dst" "$remote"; then
            deny trunk-delete "deleting the trunk branch '$dst' on the remote is not allowed; leave the trunk alone"
        fi
        if [ $forced = 1 ] && is_trunk "$dst" "$remote"; then
            deny trunk-force-push "force-pushing the trunk branch '$dst' is not allowed; push to a feature branch and open a PR, or add a new commit instead of rewriting"
        fi
    done
    if [ $force = 1 ] && [ $all = 1 ]; then
        deny trunk-force-push "force-pushing with --all or --mirror would overwrite the trunk; push the one feature branch by name"
    fi
    if [ $force = 1 ] && [ ${#refs[@]} -eq 0 ]; then
        cur_branch; cur="$CUR_VAL"
        if is_trunk "$cur" "$remote"; then
            deny trunk-force-push "force-pushing while on the trunk branch '$cur' is not allowed; switch to a feature branch or add a new commit"
        fi
    fi
}

check_gh() { # check_gh <args...>
    local a skip=0 stage=0 cluster ch i
    for a in "$@"; do
        if [ $skip = 1 ]; then skip=0; continue; fi
        if [ $stage -lt 2 ]; then
            case "$a" in
                -R|--repo|--hostname) skip=1 ;;
                -*) ;;
                pr) if [ $stage = 0 ]; then stage=1; else return 0; fi ;;
                review) if [ $stage = 1 ]; then stage=2; else return 0; fi ;;
                *) return 0 ;;
            esac
            continue
        fi
        case "$a" in
            --approve|--approve=*) deny pr-approve "approving a PR is the human's call; leave the review at --comment or --request-changes and report to the user" ;;
            -b|--body|-F|--body-file|-R|--repo) skip=1 ;;
            --*) ;;
            -?*)
                cluster="${a#-}"; cluster="${cluster:0:32}"
                for ((i = 0; i < ${#cluster}; i++)); do
                    ch="${cluster:i:1}"
                    case "$ch" in
                        a) deny pr-approve "approving a PR is the human's call; leave the review at --comment or --request-changes and report to the user" ;;
                        b|F|R) [ $((i + 1)) -eq ${#cluster} ] && skip=1; break ;;
                    esac
                done ;;
        esac
    done
}

# Raw-text pass: backslashes, backticks and ( ) { } become spaces, ; & | and
# newlines split segments, and quote characters become spaces after being counted.
# A segment that ends with an odd number of ' or " is joined to the next one (the
# separator was probably inside a quoted message), so a flag after a multi-line
# or `;` message is still read as part of the command. awk prints each segment
# that has a git commit/push, a gh pr review or a cd in it, words joined by $US.
segments() {
    # shellcheck disable=SC2020 # three separators map to three newlines on purpose
    # a backslash-newline continues the command: join the lines. >& <& &> are
    # redirections, not separators.
    printf '%s' "$1" | LC_ALL=C awk '{ if (sub(/\\$/, " ")) printf "%s", $0; else print }' |
        sed -e 's/&>/> /g' -e 's/>&/> /g' -e 's/<&/< /g' |
        tr '\134\140(){}' '     ' | tr ';&|' '\n\n\n' |
        LC_ALL=C awk '
        function show(   q) {
            if (rel) { for (q = 0; q < k; q++) printf "%s%s", (q ? "\037" : ""), O[q]; printf "\n" }
            k = 0; git = 0; gh = 0; rel = 0; dq = 0; sq = 0
        }
        {
            dq += gsub(/"/, " "); sq += gsub(/\047/, " ")
            gsub(/[0-9]*[<>]+&?[^ \t]*/, " ")   # drop redirections: main>/dev/null, git>x commit
            n = split($0, W, /[ \t]+/)
            for (j = 1; j <= n; j++) {
                w = W[j]
                if (w == "") continue
                O[k++] = w
                if (w ~ /(^|\/)git$/) git = 1
                else if (w ~ /(^|\/)gh$/) gh = 1
                else if (git && (w == "commit" || w == "push")) rel = 1
                else if (gh && w == "review") rel = 1
                else if (w == "cd") rel = 1
            }
            if (dq % 2 == 0 && sq % 2 == 0) show()
        }
        END { show() }'
}

# charge: every git or gh word rescans the rest of its segment, so bound the total
# work (T and i are the caller's words and position).
charge() {
    WORDS_LEFT=$((WORDS_LEFT - ${#T[@]} + i))
    [ $WORDS_LEFT -ge 0 ] || deny too-large "too many words after git or gh commands to inspect; split the command"
}

check_segment() { # check_segment <words joined by $US>
    local T=() i=0 t j gwd sub saved
    IFS="$US" read -r -a T <<<"$1"
    while [ $i -lt ${#T[@]} ]; do
        t="${T[$i]}"; i=$((i + 1))
        [ ${#t} -le 256 ] || continue   # no command name is that long; the suffix strip below is quadratic on long words
        case "${t##*/}" in
            cd)
                if [ $i -lt ${#T[@]} ] && [ "${T[$i]}" != "-" ]; then
                    case "${T[$i]}" in /*) WD="${T[$i]}" ;; *) WD="$WD/${T[$i]}" ;; esac
                    [ ${#WD} -le 4096 ] || deny too-large "the working directory path is too long to track; use shorter paths"
                fi ;;
            git)
                charge
                gwd="$WD"; sub=""; j=$i
                while [ $j -lt ${#T[@]} ]; do
                    t="${T[$j]}"; j=$((j + 1))
                    case "$t" in
                        -C)
                            if [ $j -lt ${#T[@]} ]; then
                                case "${T[$j]}" in /*) gwd="${T[$j]}" ;; *) gwd="$gwd/${T[$j]}" ;; esac
                                [ ${#gwd} -le 4096 ] || deny too-large "the git -C path is too long to track; use shorter paths"
                                j=$((j + 1))
                            fi ;;
                        -c|--git-dir|--work-tree|--namespace|--exec-path|--config-env) j=$((j + 1)) ;;
                        -*) ;;
                        *) sub="$t"; break ;;
                    esac
                done
                saved="$WD"; WD="$gwd"
                case "$sub" in
                    commit) check_commit_push commit "${T[@]:$j}" ;;
                    push) check_commit_push push "${T[@]:$j}"; check_push "${T[@]:$j}" ;;
                esac
                WD="$saved" ;;
            gh) charge; check_gh "${T[@]:$i}" ;;
        esac
    done
}

WORDS_LEFT=100000   # words handed to the rules, over all git and gh commands
NSEG=0
while IFS= read -r seg; do
    NSEG=$((NSEG + 1))
    [ $NSEG -le 500 ] || deny too-large "more than 500 git or gh commands in one call, too many to inspect; split it up"
    check_segment "$seg"
done <<<"$(segments "$command_str")"
exit 0
