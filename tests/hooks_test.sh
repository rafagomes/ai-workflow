#!/usr/bin/env bash
# Tests for hooks/guard.sh: feeds hook-input JSON on stdin and checks the exit
# code (2 = blocked, 0 = allowed) and that stderr names the rule.
#
# Usage: bash tests/hooks_test.sh
# shellcheck disable=SC2016 # fixtures are literal command text, not expansions
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$REPO/hooks/guard.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASH_BIN="$(command -v bash)"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

# A throwaway repo on branch main whose origin/HEAD points at "trunk".
REPO_T="$TMP/repo"
git init -q -b main "$REPO_T"
git -C "$REPO_T" update-ref refs/remotes/origin/trunk HEAD 2>/dev/null
git -C "$REPO_T" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
# A second repo on a feature branch with the same origin/HEAD.
REPO_F="$TMP/feat"
git init -q -b feat/x "$REPO_F"
git -C "$REPO_F" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
# A repo on the default branch "trunk".
REPO_D="$TMP/dflt"
git init -q -b trunk "$REPO_D"
git -C "$REPO_D" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk

# payload <command> <cwd>: hook JSON, encoded with jq or python3.
payload() {
    if command -v jq >/dev/null 2>&1; then
        jq -n --arg c "$1" --arg d "$2" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'
    else
        python3 -I -c 'import json,sys; print(json.dumps({"tool_name":"Bash","cwd":sys.argv[2],"tool_input":{"command":sys.argv[1]}}))' "$1" "$2"
    fi
}

# run <command> <cwd> -> sets RC and ERR
run() {
    ERR="$(payload "$1" "$2" | "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)"
    RC=$?
}
# blocked <rule> <command> [cwd]
blocked() {
    run "$2" "${3:-$REPO_T}"
    if [ "$RC" -ne 2 ]; then fail "should block ($1): $2 (rc=$RC)"
    elif [[ "$ERR" != *"[$1]"* ]]; then fail "stderr should name rule $1: $2 (got: $ERR)"
    else ok; fi
}
# allowed <command> [cwd]
allowed() {
    run "$1" "${2:-$REPO_T}"
    if [ "$RC" -ne 0 ]; then fail "should allow: $1 (rc=$RC, $ERR)"; else ok; fi
}

# --- no-verify
blocked no-verify 'git commit --no-verify -m x'
blocked no-verify 'git commit -n -m x'
blocked no-verify 'git commit -nm "msg"'
blocked no-verify 'git commit -m "msg" -n'
blocked no-verify 'git commit --amend --no-verify'
blocked no-verify 'git -C /tmp/x commit --no-verify -m x'
blocked no-verify 'git -c user.name=a commit -n'
blocked no-verify 'git push --no-verify'
blocked no-verify 'git push --no-verify origin feat/x'
blocked no-verify 'GIT_AUTHOR_NAME=a git commit -n'
allowed 'git commit -m -n'
allowed 'git commit -am "msg"'
allowed 'git push -n'
allowed 'git push --dry-run origin feat/x'
allowed 'git log --no-verify-signatures'
allowed 'git status -n'
blocked no-verify 'git commit -- -n'   # a -- is not honoured: it may sit inside a message

# --- trunk force push
blocked trunk-force-push 'git push --force origin main'
blocked trunk-force-push 'git push -f origin main'
blocked trunk-force-push 'git push origin main -f'
blocked trunk-force-push 'git push --force-with-lease origin main'
blocked trunk-force-push 'git push --force-with-lease=main:abc origin main'
blocked trunk-force-push 'git push --force-if-includes origin master'
blocked trunk-force-push 'git push origin +main'
blocked trunk-force-push 'git push origin +HEAD:main'
blocked trunk-force-push 'git push origin +refs/heads/master'
blocked trunk-force-push 'git push -f origin feat/x:main'
blocked trunk-force-push 'git push --force'                 # no refspec, current branch is main
blocked trunk-force-push 'git push -f origin HEAD'          # HEAD resolves to main
blocked trunk-force-push 'git push -fu origin main'
blocked trunk-force-push 'git push -f origin trunk'         # repo default branch from origin/HEAD
blocked trunk-force-push 'git push --force' "$REPO_D"       # on the default branch, no refspec
blocked trunk-force-push 'git push --all --force'
blocked trunk-force-push 'cd /tmp && git push -f origin main'
blocked trunk-force-push 'git status; git push -f origin main'
blocked trunk-force-push 'echo hi | git push -f origin main'
blocked trunk-force-push 'true &&
git push -f origin main'
blocked trunk-force-push 'GIT_TRACE=1 git push -f origin main'
blocked trunk-force-push 'bash -c "git push -f origin main"'
blocked trunk-force-push 'git push -f origin main 2>&1'
blocked trunk-force-push "cd $REPO_T && git push --force"
blocked trunk-force-push "git -C $REPO_T push --force"
allowed 'git push -f origin feat/x'
allowed 'git push --force-with-lease origin feat/x'
allowed 'git push origin +feat/x'
allowed 'git push --force' "$REPO_F"                        # feature branch, no refspec
allowed 'git push -f origin HEAD' "$REPO_F"
allowed 'git push origin main'
allowed 'git push -u origin feat/x'
allowed 'git push --force-with-lease origin main-fix'
allowed 'git push -f origin trunk-next'
allowed "cd $REPO_F && git push --force"
allowed 'git log main -f'
allowed 'grep -- --force file'
allowed "git push -f origin 'feat/x'"

# --- text that literally contains a forbidden command is blocked (documented false
# positive): the guard reads raw text, so quoting, heredocs and $(...) do not hide it.
# Workarounds: git commit -F <file>, gh pr create|comment --body-file <file>, WF_GUARD=off.
blocked no-verify $'git commit -m "$(cat <<\'EOF\'\nfix: say "use -n" in docs\nEOF\n)"'
blocked no-verify $'git commit -m "$(cat <<\'EOF\'\ndocs: explain "never pass --no-verify"\nEOF\n)"'
blocked trunk-force-push $'git commit -m "$(cat <<\'EOF\'\ndocs: one " quote\ngit push -f origin main\nEOF\n)"'
blocked pr-approve $'gh pr review 3 --comment -b "$(cat <<\'EOF\'\nsay "gh pr review --approve" is human only\nEOF\n)"'
blocked no-verify $'git commit -m "$(printf %s "a (nested) \\"-n\\"")" && git status'
blocked no-verify $'git commit -m "$(echo \'(\') say \\"-n\\""'
blocked no-verify 'git commit -m "fix -n handling" -a'
blocked no-verify 'git commit -m "a --no-verify b"'
blocked trunk-force-push 'echo "git push -f origin main"'
blocked trunk-force-push 'git commit -m "never git push --force origin main"'
blocked pr-approve 'gh pr review 12 --comment -b "do not --approve yet"'
blocked trunk-force-push "echo '\$(git push -f origin main)'"

# --- quoting, escapes, backticks, substitutions and wrappers cannot hide a command
blocked trunk-force-push 'echo '"'"'`'"'"'; echo "`git push -f origin main`"'
blocked no-verify 'echo "\`" "`git commit -n -m x`"'
blocked pr-approve 'echo \` "`gh pr review 7 --approve`"'
blocked no-verify 'echo "$(case x in x) git commit -n -m y;; esac)"'
blocked trunk-delete 'x="$(case a in a) git push origin :main;; esac)"'
blocked no-verify $'echo "$(echo x # )\ngit commit -n -m x\n)"'
blocked no-verify 'timeout 5 git commit -n -m x'
blocked no-verify 'nice -n 5 git commit -n -m x'
blocked no-verify 'bash <<< "git commit -n -m x"'
blocked no-verify 'eval "$(echo git commit -n -m x)"'
blocked no-verify 'echo a | xargs git commit -n -m'
blocked trunk-force-push 'sudo -u u git push -f origin main'
blocked trunk-force-push 'out="$(git push -f origin main 2>&1)"'
blocked no-verify 'echo "$(git commit --no-verify -m x)"'
blocked pr-approve 'echo "$(gh pr review 1 --approve)"'
blocked no-verify 'echo "`git commit --no-verify`"'
blocked no-verify 'echo $(git commit -n -m x)'
blocked trunk-force-push 'x=`git push --force origin main`'
blocked no-verify 'echo "$(echo "$(git commit --no-verify -m x)")"'
blocked trunk-force-push 'echo "$(echo "$(echo "$(echo "$(echo "$(git push -f origin main)")")")")"'
blocked trunk-force-push $'git commit -m "$(printf $\'\\\'\')" && git push -f origin main; echo \')\''
blocked no-verify $'git commit -m "$(echo hi # don\'t\n)" --no-verify; echo \')\''
# flags after a multi-line or `;` message, with balanced and unbalanced quotes
blocked no-verify $'git commit -m "$(cat <<\'EOF\'\nfeat: add x (see #3\nEOF\n)" --no-verify'
blocked no-verify $'git commit -m "$(cat <<\'EOF\'\nsmile :(\nEOF\n)" --no-verify'
blocked no-verify $'git commit -m "$(cat <<\'EOF\'\nit\'s a) item\nEOF\n)" -n'
blocked no-verify $'git commit -m "$(cat <<\'EOF\'\nx "quoted"\nEOF\n)" --no-verify'
blocked no-verify 'git commit -m "a; b" -n'
blocked no-verify $'git commit -m "line one\nline two" --no-verify'
blocked trunk-force-push $'git commit -m "$(cat <<\'EOF\'\nsmile :(\nEOF\n)" && git push -f origin main'
blocked no-verify 'git commit -m "$(echo ("  --no-verify'
blocked no-verify 'git commit -m "$(echo \()" --no-verify'
blocked no-verify $'git commit -m "$(echo \'(\')" --no-verify'

# --- round 6: bypasses found in review
# line continuations
blocked no-verify $'git commit -m x \\\n --no-verify'
blocked trunk-force-push $'git push -f origin \\\nmain'
blocked pr-approve $'gh pr review 12 \\\n --approve'
# a -- inside a message must not hide later flags
blocked no-verify 'git commit -m "fix -- tidy" --no-verify'
blocked no-verify $'git commit -m "$(cat <<\'EOF\'\nfix -- tidy\nEOF\n)" --no-verify'
blocked trunk-force-push 'git push -f -- origin main'
# redirections are not part of a word
blocked trunk-force-push 'git push -f origin main>/dev/null'
blocked trunk-force-push 'git push -f origin main<x'
blocked trunk-force-push 'git push -f origin main>&2'
blocked no-verify 'git commit --no-verify>/dev/null -m x'
blocked no-verify 'git>/dev/null commit --no-verify'
blocked no-verify 'git commit -m x 2>&1 --no-verify'
# git accepts unambiguous long-option prefixes
blocked no-verify 'git commit --no-verif -m x'
blocked no-verify 'git commit --no-veri -m x'
blocked no-verify 'git push --no-verif'
blocked trunk-force-push 'git push --force-w origin main'
blocked trunk-force-push 'git push --force-with origin main'
blocked trunk-force-push 'git push --force-i origin main'
blocked trunk-force-push 'git push --for origin main'
blocked trunk-delete 'git push --delet origin main'
blocked trunk-delete 'git push --de origin master'
blocked trunk-force-push 'git push --mirro origin'
blocked trunk-force-push 'git push --al --force-w'
allowed 'git push --follow-tags origin feat/x'
allowed 'git push --dry-run --atomic origin feat/x'
allowed 'git push --force-with-lease origin feat/x'
allowed 'git commit --amend --no-edit -m x'
# other spellings of the trunk
blocked trunk-force-push 'git push origin +HEAD:heads/main'
blocked trunk-force-push 'git push -f origin heads/main'
blocked trunk-force-push 'git push -f origin HEAD:refs/heads/master'
blocked trunk-force-push 'git push -f origin @'
blocked trunk-force-push 'git push -f origin @:main'
blocked trunk-delete 'git push --delete origin heads/main'
allowed 'git push -f origin @' "$REPO_F"
# --mirror force-updates every ref, the trunk included
blocked trunk-force-push 'git push --mirror'
blocked trunk-force-push 'git push --mirror backup'
# gh: -a=true and grouped short flags
blocked pr-approve 'gh pr review 1 -a=true'
blocked pr-approve 'gh pr review 1 -ab ok'
blocked pr-approve 'gh pr review 1 -ca'
allowed 'gh pr review 1 -ba'
allowed 'gh pr review 1 -c -b "ok"'
# a long message that mentions git many times is fine (bounded work, not a block)
msg=""
for i in $(seq 1 40); do msg="$msg git is used here and there, with many other words in this sentence number $i of the body,"; done
allowed "git commit -m \"\$(cat <<'EOF'"$'\n'"$msg"$'\nEOF\n)"'

# --- ordinary work stays allowed
allowed 'git push origin a && git push origin b && git push --tags'
allowed 'git push -u origin feat/a; git push origin feat/b; git push --tags; git push origin :feat/old'
allowed "$(printf 'git push -f origin feat/x;%.0s ' 1 2 3 4 5 6 7 8 9 10)" "$REPO_F"
allowed 'git log -n 5'
allowed 'git log --oneline -n 5 && git status'
allowed 'git push --dry-run origin feat/x'
allowed 'git push -n origin feat/x'
allowed 'gh pr review 3 --comment -b "looks good"'
allowed 'git commit -m "msg" && git log -n 3'
allowed 'echo "$(git log --oneline -3)" > /dev/null'
allowed 'for f in a b; do git add "$f"; done; git commit -m "add files"'
allowed 'ls -n; cd /tmp && git status'
allowed $'git commit -m "$(cat <<\'EOF\'\nfeat: add (see #3) and say "hi"\nEOF\n)"'
allowed $'git commit -m "$(cat <<\'EOF\'\nfeat: add x (see #3 \nsay "hi" :(\na) item\nEOF\n)"'
allowed $'git commit -m "$(cat <<\'EOF\'\ndon\'t stop (see #3 a) item\nEOF\n)"'
allowed $'git commit -m "$(cat <<\'EOF\'\nfix: handle `a/b.go`, `c.go`\n\n- a) item (x\nEOF\n)"'
body=""
for i in $(seq 1 60); do body="$body- use \`path/file$i.go\` and \`helper$i\` here"$'\n'; done
allowed "gh pr create --title t --body \"\$(cat <<'EOF'"$'\n'"$body"$'EOF\n)"'
allowed "git commit -m \"\$(cat <<'EOF'"$'\n'"$body"$'EOF\n)"'

# --- trunk delete
blocked trunk-delete 'git push origin --delete main'
blocked trunk-delete 'git push --delete origin master'
blocked trunk-delete 'git push origin -d main'
blocked trunk-delete 'git push origin :main'
blocked trunk-delete 'git push origin :refs/heads/master'
blocked trunk-delete 'git push origin --delete trunk'
allowed 'git push origin --delete feat/x'
allowed 'git push origin :feat/x'
allowed 'git push origin --delete main-old'

# --- gh pr review --approve
blocked pr-approve 'gh pr review 12 --approve'
blocked pr-approve 'gh pr review --approve -b ok'
blocked pr-approve 'gh pr review 12 -a'
blocked pr-approve 'gh -R owner/repo pr review 12 --approve'
blocked pr-approve 'gh pr review -R owner/repo 12 --approve=true'
blocked pr-approve 'cd x && gh pr review --approve'
blocked pr-approve 'sh -c "gh pr review 3 --approve"'
allowed 'gh pr review 12 --request-changes -b "-a"'
allowed 'gh pr view 12'
allowed 'gh pr merge 12'
allowed 'gh issue list --approve'

# --- misc
allowed 'ls -la'
allowed ''
allowed 'echo "unterminated'

# --- a command over 128 KB is blocked (too large to inspect), a big one under it is not
big() { printf '{"tool_name":"Bash","tool_input":{"command":"echo '; head -c "$1" /dev/zero | tr '\0' 'a'; printf '"}}'; }
RC=0; ERR="$(big 1100000 | "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)" || RC=$?
if [ "$RC" -eq 2 ] && [[ "$ERR" == *"[too-large]"* ]]; then ok; else fail "over 1 MB should be blocked (rc=$RC)"; fi
RC=0; ERR="$(big 200000 | "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)" || RC=$?
if [ "$RC" -eq 2 ] && [[ "$ERR" == *"[too-large]"* ]]; then ok; else fail "200 KB should be blocked (rc=$RC)"; fi
RC=0; big 100000 | "$BASH_BIN" "$GUARD" >/dev/null 2>&1 || RC=$?
if [ "$RC" -eq 0 ]; then ok; else fail "100 KB word should be allowed (rc=$RC)"; fi

# --- more than 500 git commit/push or gh pr review segments in one call is blocked
many=""
for _ in $(seq 1 600); do many="${many}git commit -m x; "; done
blocked too-large "$many"
many=""
for _ in $(seq 1 100); do many="${many}git commit -m x; "; done
allowed "$many"

# --- crafted inputs finish well inside the hook timeout (a timeout does not block)
if command -v jq >/dev/null 2>&1 && [[ "$(date +%s%N)" =~ ^[0-9]+$ ]]; then
    timed_blocked() { # timed_blocked <label> <command> [limit ms] [inner: no deadline wrapper]
        local t0 t1 ms limit="${3:-2000}" cwd="${5:-/tmp}"
        t0=$(date +%s%N)
        ERR="$(printf '%s' "$2" | jq -Rs --arg d "$cwd" '{tool_name:"Bash",cwd:$d,tool_input:{command:.}}' | env ${4:+WF_GUARD_INNER=1} "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)"; RC=$?
        t1=$(date +%s%N); ms=$(( (t1 - t0) / 1000000 ))
        if [ "$RC" -ne 2 ]; then fail "$1 should be blocked (rc=$RC)"
        elif [ "$ms" -ge "$limit" ]; then fail "$1 took ${ms} ms (limit $limit)"
        else ok; fi
    }
    rep() { yes -- "$1" | head -n "$2" | tr -d '\n'; }
    timed_blocked "22 KB of git commit words" "$(rep 'git commit ' 2000); git commit --no-verify"
    timed_blocked "1 MB of git push words" "$(rep 'git push ' 100000)"
    timed_blocked "gh pr review words" "$(rep 'gh pr review ' 80000); gh pr review --approve"
    timed_blocked "git words with a flag at the end" "$(rep 'git commit ' 2000) --no-verify"
    # the hook timeout is non-blocking, so the worst crafted inputs must still be blocked in time
    timed_blocked "32-letter short-flag groups" "$(rep 'git commit -abcdefghijklmnopqrstuvwxyzabcdef ' 2800); git commit --no-verify" 7000
    timed_blocked "--xx words through is_opt" "$(rep 'git commit --xx ' 7500); git commit --no-verify" 7000
    timed_blocked "one huge --aaa word" "git commit --$(head -c 120000 /dev/zero | tr '\0' a) --no-verify" 7000
    timed_blocked "one huge --aaa word after push" "git push --$(head -c 120000 /dev/zero | tr '\0' a); git push -f origin main" 7000
    timed_blocked "cd a cd a ..." "$(rep 'cd a ' 24000); git commit --no-verify" 7000
    # the same shapes at the old 1 MB cap: blocked at once by the 128 KB cap, not after seconds of work
    timed_blocked "900 KB of 32-letter short-flag groups" "$(rep 'git commit -abcdefghijklmnopqrstuvwxyzabcdef ' 24000); git commit --no-verify" 3000
    timed_blocked "900 KB of --xx words" "$(rep 'git commit --xx ' 55000); git commit --no-verify" 3000
    timed_blocked "one 900 KB --aaa word" "git commit --$(head -c 900000 /dev/zero | tr '\0' a) --no-verify" 3000
    timed_blocked "750 KB of cd a" "$(rep 'cd a ' 150000); git commit --no-verify" 3000
    # hosts without timeout/gtimeout have no deadline: the caps alone must bound the work
    blocked too-large "git push origin $(rep 'x ' 300)"
    # many pushes must not add up to a timeout: the git lookups of a whole command are counted
    lines="$(yes 'git push -f' | head -n 450)"$'\n'
    timed_blocked "450 bare force pushes then a push to main, no deadline" "${lines}git push --force origin main" 800 inner "$REPO_F"
    timed_blocked "one segment of 400 git push -f words, no deadline" "$(rep 'git push -f ' 400); git push --force origin main" 800 inner "$REPO_F"
    blocked too-large "${lines}git push --force origin main" "$REPO_F"
    timed_blocked "7000 refs in one push, no deadline" "git push -f origin $(rep 'x ' 7000)main" 3000 inner
    timed_blocked "256 refs ending in main, no deadline" "git push -f origin $(rep 'x ' 255)main" 3000 inner
    timed_blocked "git -C a chain at 128 KB, no deadline" "git $(rep '-C a ' 25000) commit --no-verify" 3000 inner
    timed_blocked "cd with a long path" "cd $(head -c 100000 /dev/zero | tr '\0' a); git commit --no-verify" 7000
fi

# --- the analysis runs under a deadline and a timeout blocks (exit 0 or 2 only)
mkdir -p "$TMP/tmo124" "$TMP/tmo137" "$TMP/tmo1"
printf '#!/bin/sh\nexit 124\n' > "$TMP/tmo124/timeout"; chmod +x "$TMP/tmo124/timeout"
printf '#!/bin/sh\nexit 137\n' > "$TMP/tmo137/timeout"; chmod +x "$TMP/tmo137/timeout"
printf '#!/bin/sh\nexit 1\n' > "$TMP/tmo1/timeout"; chmod +x "$TMP/tmo1/timeout"
for d in tmo124 tmo137; do
    RC=0; ERR="$(payload 'ls' "$REPO_T" | PATH="$TMP/$d:$PATH" "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)" || RC=$?
    if [ "$RC" -eq 2 ] && [[ "$ERR" == *"[too-slow]"* ]]; then ok; else fail "a timed-out analysis ($d) should block (rc=$RC, $ERR)"; fi
done
RC=0; ERR="$(payload 'ls' "$REPO_T" | PATH="$TMP/tmo1:$PATH" "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)" || RC=$?
if [ "$RC" -eq 0 ] && [[ "$ERR" == *"guard failed"* ]]; then ok; else fail "a crashed analysis should fail open with a warning (rc=$RC, $ERR)"; fi
# the real deadline: 1 ms is far too short to finish, so the command is blocked
RC=0; ERR="$(payload 'ls' "$REPO_T" | WF_GUARD_TIMEOUT=0.001 "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)" || RC=$?
if command -v timeout >/dev/null 2>&1 || command -v gtimeout >/dev/null 2>&1; then
    if [ "$RC" -eq 2 ] && [[ "$ERR" == *"[too-slow]"* ]]; then ok; else fail "a 1 ms deadline should block (rc=$RC, $ERR)"; fi
fi

# --- non-Bash tool calls and bad input are not blocked
RC=0; ERR="$(printf '%s' '{"tool_name":"Edit","tool_input":{"command":"git push -f origin main"}}' | "$BASH_BIN" "$GUARD" 2>&1)" || RC=$?
if [ "$RC" -eq 0 ]; then ok; else fail "non-Bash tool should be allowed"; fi
RC=0; ERR="$(printf '%s' 'not json' | "$BASH_BIN" "$GUARD" 2>&1)" || RC=$?
if [ "$RC" -eq 0 ]; then ok; else fail "invalid JSON should fail open (rc=$RC)"; fi

# --- escape hatch: WF_GUARD=off in the hook's environment allows everything
RC=0; payload 'git push --force origin main' "$REPO_T" | WF_GUARD=off "$BASH_BIN" "$GUARD" >/dev/null 2>&1 || RC=$?
if [ "$RC" -eq 0 ]; then ok; else fail "WF_GUARD=off should allow (rc=$RC)"; fi
# set inline in the command it does nothing
blocked trunk-force-push 'WF_GUARD=off git push --force origin main'
# other values do not disable it
RC=0; payload 'git push --force origin main' "$REPO_T" | WF_GUARD=on "$BASH_BIN" "$GUARD" >/dev/null 2>&1 || RC=$?
if [ "$RC" -eq 2 ]; then ok; else fail "WF_GUARD=on should not disable the guard (rc=$RC)"; fi

# --- missing tools: simulate by a PATH holding every tool except jq / python3
mkbin() { # mkbin <dir> <excluded tool...>
    local dir="$1" t p x skip; shift
    mkdir -p "$dir"
    for t in awk cat git dirname sed tr grep head mktemp rm env jq python3; do
        skip=0
        for x in "$@"; do [ "$x" = "$t" ] && skip=1; done
        [ $skip = 1 ] && continue
        p="$(command -v "$t" 2>/dev/null)" || continue
        ln -sf "$p" "$dir/$t"
    done
}
BAD="$(payload 'git push --force origin main' "$REPO_T")"
if command -v python3 >/dev/null 2>&1; then
    mkbin "$TMP/nojq" jq
    RC=0; ERR="$(printf '%s' "$BAD" | PATH="$TMP/nojq" "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)" || RC=$?
    if [ "$RC" -eq 2 ] && [[ "$ERR" == *"[trunk-force-push]"* ]]; then ok; else fail "without jq the python3 fallback should block (rc=$RC, $ERR)"; fi
fi
mkbin "$TMP/nojqpy" jq python3
RC=0; ERR="$(printf '%s' "$BAD" | PATH="$TMP/nojqpy" "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)" || RC=$?
if [ "$RC" -eq 0 ] && [[ "$ERR" == *"neither jq nor python3"* ]]; then ok; else fail "without jq and python3 the guard should fail open with a warning (rc=$RC, $ERR)"; fi

# --- no timeout or gtimeout: a perl alarm is the deadline (skipped without perl)
if command -v perl >/dev/null 2>&1; then
    mkbin "$TMP/noTmo"
    ln -sf "$BASH_BIN" "$TMP/noTmo/bash"; ln -sf "$(command -v perl)" "$TMP/noTmo/perl"
    RC=0; ERR="$(payload 'ls' "$REPO_T" | WF_GUARD_TIMEOUT=0.001 PATH="$TMP/noTmo" "$BASH_BIN" "$GUARD" 2>&1 >/dev/null)" || RC=$?
    if [ "$RC" -eq 2 ] && [[ "$ERR" == *"[too-slow]"* ]]; then ok; else fail "the perl deadline should block a slow analysis (rc=$RC, $ERR)"; fi
    RC=0; payload 'git push --force origin main' "$REPO_T" | PATH="$TMP/noTmo" "$BASH_BIN" "$GUARD" >/dev/null 2>&1 || RC=$?
    if [ "$RC" -eq 2 ]; then ok; else fail "under the perl deadline a forbidden command is still blocked (rc=$RC)"; fi
    RC=0; payload 'git status' "$REPO_T" | PATH="$TMP/noTmo" "$BASH_BIN" "$GUARD" >/dev/null 2>&1 || RC=$?
    if [ "$RC" -eq 0 ]; then ok; else fail "under the perl deadline an ordinary command is allowed (rc=$RC)"; fi
fi

# --- the hook manifest points at the guard
if command -v jq >/dev/null 2>&1; then
    cmd="$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$REPO/hooks/hooks.json")"
    mt="$(jq -r '.hooks.PreToolUse[0].matcher' "$REPO/hooks/hooks.json")"
    # shellcheck disable=SC2016 # the literal ${CLAUDE_PLUGIN_ROOT} is what we look for
    if [ "$mt" = Bash ] && [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh'* ]]; then ok; else fail "hooks.json should run guard.sh on Bash (got $mt, $cmd)"; fi
fi

echo "hooks_test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
