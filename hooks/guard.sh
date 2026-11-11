#!/usr/bin/env bash
# wf guardrail hook: a PreToolUse hook on the Bash tool.
#
# Reads the hook JSON on stdin and blocks (exit 2, reason on stderr, which Claude
# Code feeds back to the model) a command that:
#   no-verify           runs `git commit` or `git push` with --no-verify (or `commit -n`)
#   trunk-force-push    force-pushes the trunk (main, master or the origin default branch)
#   trunk-delete        deletes the trunk on the remote
#   pr-approve          runs `gh pr review --approve` (approving is the human's call)
#
# This is a guardrail against mistakes, not a security boundary. It tokenizes the
# command (quotes, ; & | newlines, ( ) and backticks split commands) and looks at
# each command's first words. It does not expand variables, aliases, git aliases,
# `git -c core.hooksPath=...`, `sudo -u user git ...`, scripts, heredoc bodies
# (their lines are read as commands, a rare false positive), or `gh api`. A
# determined agent can get around it; an honest mistake is caught.
# The rules run on the command read two ways (plain quote tracking, and with a
# `$(...)` inside double quotes kept whole) and on the body of every `$(...)` and
# backtick span, recursively (depth 4, 100 spans; beyond that it blocks). The
# command is blocked if any reading blocks, so a parsing quirk fails closed.
# Known false positive: a `git commit -m "$(cat <<'EOF' ... EOF)"` message with an
# odd number of quotes around `-n`, `--no-verify` or a line starting `git push -f`
# can be blocked. Write the message to a file and use `git commit -F <file>`.
#
# Fails open: with neither jq nor python3, or JSON it cannot parse, the command is
# allowed and a one-line warning goes to stderr, so a missing tool never bricks a
# session. Escape hatch: WF_GUARD=off in the hook's own environment (set it in the
# settings `env`, not inline in the command) allows everything.

US=$'\037'   # token separator between words of one command
RS=$'\036'   # stands for a newline inside a token

warn_open() { echo "wf guard: $1; guardrails skipped for this command" >&2; exit 0; }

input=$(cat)   # always drain stdin, even when the guard is off
[ "${WF_GUARD:-}" = "off" ] && exit 0
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

deny() { # deny <rule> <message>
    printf 'wf guard [%s]: %s (WF_GUARD=off in settings env disables the guard)\n' "$1" "$2" >&2
    exit 2
}

# One awk program, three modes (aware):
#   0  tokenize with plain quote tracking
#   1  tokenize, keeping a $(...) inside double quotes in its token
#   2  print the body of every outermost $(...) and `...` span, one per line
# Tokenizing splits a command string into segments, one per line, tokens joined
# by $US; a newline inside a token is written as $RS.
# shellcheck disable=SC2016 # awk program text, not a shell expansion
AWK_PROG='
    function add(c) { tok = tok (c == "\n" ? "\036" : c); has = 1 }
    function endtok() { if (has) { seg = seg (segn++ ? "\037" : "") tok } tok = ""; has = 0 }
    function endseg() { endtok(); if (segn > 0) print seg; seg = ""; segn = 0 }
    function emit(b) { if (b != "") { gsub(/\n/, "\036", b); print b } }
    # scan_subst: end index of the $(...) starting at i, skipping quoted spans,
    # escapes and heredoc bodies; sets unterm when there is no closing paren
    function scan_subst(i,   j, depth, ch, hd, k, e, line, p, w, qc) {
        depth = 0; hd = ""; unterm = 0
        for (j = i + 1; j <= len; j++) {
            ch = substr(s, j, 1)
            if (ch == "\\") j++
            else if (ch == "\047") { j++; while (j <= len && substr(s, j, 1) != "\047") j++ }
            else if (ch == "\"") {
                j++
                while (j <= len && substr(s, j, 1) != "\"") { if (substr(s, j, 1) == "\\") j++; j++ }
            }
            else if (ch == "<" && substr(s, j + 1, 1) == "<" && substr(s, j + 2, 1) != "<") {
                p = j + 2
                if (substr(s, p, 1) == "-") p++
                while (substr(s, p, 1) == " " || substr(s, p, 1) == "\t") p++
                qc = substr(s, p, 1)
                if (qc == "\047" || qc == "\"") p++
                w = ""
                while (substr(s, p, 1) ~ /[A-Za-z0-9_]/) { w = w substr(s, p, 1); p++ }
                if (w != "" && (qc == "\047" || qc == "\"") && substr(s, p, 1) == qc) p++
                if (w != "") hd = w
                j = p - 1
            }
            else if (ch == "\n" && hd != "") {
                k = j + 1
                while (1) {
                    if (k > len) { j = len; break }
                    for (e = k; e <= len && substr(s, e, 1) != "\n"; e++) ;
                    line = substr(s, k, e - k); sub(/^\t+/, "", line)
                    if (line == hd) { j = e - 1; hd = ""; break }
                    k = e + 1
                }
            }
            else if (ch == "(") depth++
            else if (ch == ")") { if (--depth == 0) return j }
        }
        unterm = 1
        return len
    }
    function extract(   i, j, e, ch, depth, key) {
        # A: parens counted with no quote handling
        for (i = 1; i <= len; i++) {
            if (substr(s, i, 1) == "$" && substr(s, i + 1, 1) == "(") {
                depth = 0
                for (j = i + 1; j <= len; j++) {
                    ch = substr(s, j, 1)
                    if (ch == "(") depth++
                    else if (ch == ")" && --depth == 0) break
                }
                e = (j > len) ? len : j - 1
                key[i ":" e] = 1
                emit(substr(s, i + 2, e - i - 1))
                i = (j > len) ? len : j
            }
        }
        # B: quote-aware scan; skip bodies already printed
        for (i = 1; i <= len; i++) {
            if (substr(s, i, 1) == "$" && substr(s, i + 1, 1) == "(") {
                j = scan_subst(i)
                e = unterm ? len : j - 1
                if (!((i ":" e) in key)) emit(substr(s, i + 2, e - i - 1))
                i = unterm ? len : j
            }
        }
        # C: backticks, paired in order
        for (i = 1; i <= len; i++) {
            if (substr(s, i, 1) == "`") {
                for (j = i + 1; j <= len && substr(s, j, 1) != "`"; j++) ;
                emit(substr(s, i + 1, j - i - 1))
                i = j
            }
        }
    }
    { s = s (NR > 1 ? "\n" : "") $0 }
    END {
        len = length(s); q = ""
        if (aware == 2) { extract(); exit }
        for (i = 1; i <= len; i++) {
            c = substr(s, i, 1)
            if (q == "\047") { if (c == "\047") q = ""; else add(c); continue }
            if (q == "\"") {
                if (c == "\\") {
                    d = substr(s, i + 1, 1)
                    if (d == "\"" || d == "\\" || d == "$" || d == "`") { add(d); i++ } else add(c)
                } else if (aware == 1 && c == "$" && substr(s, i + 1, 1) == "(") {
                    # $(...) inside double quotes: keep it, quotes and all, in this token
                    j = scan_subst(i)
                    sub_s = substr(s, i, j - i + 1)
                    gsub(/\n/, "\036", sub_s)
                    tok = tok sub_s; has = 1
                    i = j
                } else if (c == "\"") q = ""; else add(c)
                continue
            }
            if (c == "\047" || c == "\"") { q = c; has = 1 }
            else if (c == "\\") {
                d = substr(s, i + 1, 1); i++
                if (d != "\n") add(d)
            }
            else if (c == " " || c == "\t") endtok()
            else if (c == "#" && !has) { while (i < len && substr(s, i + 1, 1) != "\n") i++ }
            else if (c == "\n" || c == ";" || c == "&" || c == "|" || c == "(" || c == ")" || c == "`") endseg()
            else add(c)
        }
        endseg()
    }'

tokenize() { printf '%s' "$1" | LC_ALL=C awk -v aware="$2" "$AWK_PROG"; }

git_dir() { git -C "$WD" "$@" 2>/dev/null; }

current_branch() { git_dir symbolic-ref --short HEAD; }

# is_trunk <branch> <remote>: main, master, or the remote's default branch.
is_trunk() {
    local b="$1" r="${2:-origin}" d rr
    case "$b" in main|master) return 0 ;; esac
    [ -n "$b" ] || return 1
    for rr in "$r" origin; do
        d=$(git_dir symbolic-ref --short "refs/remotes/$rr/HEAD") || continue
        [ "${d#"$rr"/}" = "$b" ] && return 0
    done
    return 1
}

check_commit_push() { # check_commit_push <sub> <args...>
    local sub="$1" a cluster ch i skip=0 dd=0
    shift
    for a in "$@"; do
        if [ $skip = 1 ]; then skip=0; continue; fi
        [ $dd = 1 ] && continue
        case "$a" in
            --) dd=1 ;;
            --no-verify) deny no-verify "git $sub --no-verify skips the repo's hooks; fix what the hook reports and run it without --no-verify" ;;
            --message|--file|--reuse-message|--reedit-message|--fixup|--squash|--author|--date|--template|--cleanup)
                skip=1 ;;
            --*) ;;
            -?*)
                [ "$sub" = commit ] || continue
                cluster="${a#-}"
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
    local a cluster ch i skip=0 dd=0 force=0 del=0 all=0 remote="" have_remote=0 ref dst forced cur
    local refs=()
    for a in "$@"; do
        if [ $skip = 1 ]; then skip=0; continue; fi
        if [ $dd = 0 ] && [[ "$a" == -* ]] && [ "$a" != "-" ]; then
            case "$a" in
                --) dd=1 ;;
                --force|--force-with-lease|--force-with-lease=*|--force-if-includes) force=1 ;;
                --delete) del=1 ;;
                --all|--mirror) all=1 ;;
                --repo|--receive-pack|--exec|--push-option|--signed) skip=1 ;;
                --*) ;;
                *)
                    cluster="${a#-}"
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

    for ref in ${refs[@]+"${refs[@]}"}; do
        forced=$force
        [[ "$ref" == +* ]] && { forced=1; ref="${ref#+}"; }
        if [[ "$ref" == *:* ]]; then
            dst="${ref#*:}"
            [ -z "${ref%%:*}" ] && del=1
        else
            dst="$ref"
        fi
        dst="${dst#refs/heads/}"
        if [ "$dst" = HEAD ]; then dst=$(current_branch); fi
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
        cur=$(current_branch)
        if is_trunk "$cur" "$remote"; then
            deny trunk-force-push "force-pushing while on the trunk branch '$cur' is not allowed; switch to a feature branch or add a new commit"
        fi
    fi
}

check_gh() { # check_gh <args...>
    local a skip=0 stage=0
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
            --approve|--approve=*|-a) deny pr-approve "approving a PR is the human's call; leave the review at --comment or --request-changes and report to the user" ;;
            -b|--body|-F|--body-file|-R|--repo) skip=1 ;;
        esac
    done
}

DEPTH=0
NBODIES=0
# check_string <command string>: runs the rules on the command read two ways (plain
# quote tracking, and with $(...) inside double quotes kept whole) and blocks if
# either blocks, then on the body of every $(...) and backtick span, recursively.
check_string() {
    local segs bodies b origwd
    DEPTH=$((DEPTH + 1))
    if [ $DEPTH -gt 4 ]; then
        deny nesting "command nesting is too deep to inspect; run the steps as separate commands"
    fi
    origwd="$WD"
    check_segs "$(tokenize "$1" 1)"; WD="$origwd"
    check_segs "$(tokenize "$1" 0)"; WD="$origwd"
    bodies=$(tokenize "$1" 2)
    if [ -n "$bodies" ]; then
        while IFS= read -r b; do
            NBODIES=$((NBODIES + 1))
            if [ $NBODIES -gt 100 ]; then
                deny nesting "too many command substitutions to inspect; split the command"
            fi
            check_string "${b//$RS/$'\n'}"
            WD="$origwd"
        done <<<"$bodies"
    fi
    DEPTH=$((DEPTH - 1))
}

check_segs() { # check_segs <segments from tokenize>
    local segs="$1" line t i gwd sub saved rest w
    local T=()
    [ -n "$segs" ] || return 0
    while IFS= read -r line; do
        IFS="$US" read -r -a T <<<"$line"
        i=0
        # skip prefixes: assignments, env/command/sudo-like wrappers, shell keywords
        while [ $i -lt ${#T[@]} ]; do
            t="${T[$i]}"
            if [[ "$t" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then i=$((i + 1)); continue; fi
            case "${t##*/}" in
                env|command|exec|nohup|time|sudo|nice|builtin)
                    i=$((i + 1))
                    while [ $i -lt ${#T[@]} ] && [[ "${T[$i]}" == -* ]]; do i=$((i + 1)); done
                    continue ;;
                '!'|'{'|if|then|else|elif|do|while|until) i=$((i + 1)); continue ;;
            esac
            break
        done
        [ $i -lt ${#T[@]} ] || continue
        t="${T[$i]}"; i=$((i + 1))
        case "${t##*/}" in
            cd)
                if [ $i -lt ${#T[@]} ] && [ "${T[$i]}" != "-" ]; then
                    case "${T[$i]}" in /*) WD="${T[$i]}" ;; *) WD="$WD/${T[$i]}" ;; esac
                fi ;;
            git)
                gwd="$WD"; sub=""
                while [ $i -lt ${#T[@]} ]; do
                    t="${T[$i]}"; i=$((i + 1))
                    case "$t" in
                        -C)
                            if [ $i -lt ${#T[@]} ]; then
                                case "${T[$i]}" in /*) gwd="${T[$i]}" ;; *) gwd="$gwd/${T[$i]}" ;; esac
                                i=$((i + 1))
                            fi ;;
                        -c|--git-dir|--work-tree|--namespace|--exec-path|--config-env) i=$((i + 1)) ;;
                        -*) ;;
                        *) sub="$t"; break ;;
                    esac
                done
                saved="$WD"; WD="$gwd"
                case "$sub" in
                    commit) check_commit_push commit "${T[@]:$i}" ;;
                    push) check_commit_push push "${T[@]:$i}"; check_push "${T[@]:$i}" ;;
                esac
                WD="$saved" ;;
            gh) check_gh "${T[@]:$i}" ;;
            bash|sh|zsh|dash|ksh)
                while [ $i -lt ${#T[@]} ]; do
                    t="${T[$i]}"; i=$((i + 1))
                    if [[ "$t" == -* && "$t" != --* && "$t" == *c* ]]; then
                        [ $i -lt ${#T[@]} ] && check_string "${T[$i]//$RS/$'\n'}"
                        break
                    fi
                    [[ "$t" == -* ]] || break
                done ;;
            eval)
                rest=""
                for w in "${T[@]:$i}"; do rest="$rest $w"; done
                check_string "${rest//$RS/$'\n'}" ;;
        esac
    done <<<"$segs"
}

check_string "$command_str"
exit 0
