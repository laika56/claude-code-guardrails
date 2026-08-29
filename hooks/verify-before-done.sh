#!/usr/bin/env bash
# verify-before-done — stop the agent from reporting success over a failed command.
#
# The failure this prevents:
#   A command exits non-zero, or a test suite reports failures, and the agent
#   summarises the turn as "done" / "that's working now" without reading the
#   output. The failure is real, it is in the transcript, and nobody looks at it.
#
# How it works:
#   Runs on PostToolUse for Bash. Scans the command's combined output for
#   failure signals. If it finds one, it injects a note into the model's context
#   naming what it saw. The model cannot claim success without addressing it.
#
# This does not block the tool call. It makes the failure impossible to skip.

set -uo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ "$TOOL" != "Bash" ] && exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Reading a file that *describes* failures is not a failure. Without this the
# hook fires on `cat` of its own source, on grepping a log, on reading a test
# fixture — and a hook that cries wolf gets ignored, which is worse than no hook.
case "$CMD" in
  cat\ *|bat\ *|less\ *|head\ *|tail\ *|grep\ *|rg\ *|*--help*|*\ -h) exit 0 ;;
esac

OUT=$(printf '%s' "$INPUT" | jq -r '
  [ .tool_response.stdout?
  , .tool_response.stderr?
  , (.tool_response | if type=="string" then . else empty end)
  ] | map(select(. != null)) | join("\n")' 2>/dev/null)

[ -z "$OUT" ] && exit 0

HITS=""
add() { case "$HITS" in *"$1"*) ;; *) HITS="${HITS}${1}, " ;; esac; }

printf '%s' "$OUT" | grep -qiE 'exit (code )?[1-9][0-9]{0,2}\b'          && add "non-zero exit"
# Test runners print "fail 0" on success. Only a non-zero count is a failure.
printf '%s' "$OUT" | grep -qiE '(^|[^0-9])fail(ed|ing|ures)?[: ]+[1-9]'  && add "failing tests"
printf '%s' "$OUT" | grep -qiE '[1-9][0-9]* (test(s)? )?(fail|failing|failed)' && add "failing tests"
printf '%s' "$OUT" | grep -qiE 'ENOTFOUND|ECONNREFUSED|fetch failed|timed out' && add "network failure"
printf '%s' "$OUT" | grep -qiE 'permission denied|EACCES|not permitted'  && add "permission denied"
printf '%s' "$OUT" | grep -qiE 'Traceback \(most recent call last\)|panic:|Segmentation fault' && add "crash"

[ -z "$HITS" ] && exit 0
HITS="${HITS%, }"

MSG="The command that just ran shows failure signals: ${HITS}.

Do NOT report this turn as done, fixed, working, or passing until you have
addressed it. Required:
  1. Read the actual output and exit code. Do not infer them.
  2. State plainly what failed and why.
  3. Anything you could not verify, label as unverified.

Summarising a failure as a success is the specific thing this check exists to stop."

jq -n --arg msg "$MSG" '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$msg}}'
exit 0
