#!/usr/bin/env bash
# loop-breaker — interrupt the agent when it is retrying instead of thinking.
#
# The failure this prevents:
#   The agent hits an ambiguous signal, retries the same tool with a slightly
#   different argument, gets another ambiguous signal, retries again. It looks
#   like progress. It is the single most expensive failure mode in a long
#   session, because each retry is cheap and the twentieth one is not.
#
# How it works:
#   Counts consecutive calls to the same tool. Using a different tool resets the
#   counter, so ordinary work never trips it - only actual repetition does. Past
#   the threshold it injects a note telling the agent to stop and choose a
#   different move.
#
# Tuning:
#   SKIP_TOOLS holds the tools you legitimately use in long runs. Read/Grep/Bash
#   in a row is normal investigation, not a loop. An early version without this
#   list fired on a healthy code review at five Bash calls and had to be reverted.
#   If a tool of yours trips it wrongly, add it here rather than raising the
#   threshold - a higher threshold hides real loops too.

set -uo pipefail

SKIP_TOOLS="${GUARDRAILS_LOOP_SKIP:-Bash Read Grep Glob Edit Write TodoWrite Task}"
THRESHOLD="${GUARDRAILS_LOOP_THRESHOLD:-5}"

STATE_DIR="${TMPDIR:-/tmp}/claude-guardrails"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ -z "$TOOL" ] && exit 0

for skip in $SKIP_TOOLS; do
  [ "$TOOL" = "$skip" ] && exit 0
done

SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // "nosession"' 2>/dev/null)
STATE_FILE="$STATE_DIR/${SESSION}.loop"

LAST_TOOL=""; COUNT=0
if [ -f "$STATE_FILE" ]; then
  LAST_TOOL=$(head -1 "$STATE_FILE" 2>/dev/null)
  COUNT=$(sed -n '2p' "$STATE_FILE" 2>/dev/null)
fi
case "$COUNT" in ''|*[!0-9]*) COUNT=0 ;; esac

if [ "$TOOL" = "$LAST_TOOL" ]; then COUNT=$((COUNT + 1)); else COUNT=1; fi
printf '%s\n%s\n' "$TOOL" "$COUNT" > "$STATE_FILE"

[ "$COUNT" -lt "$THRESHOLD" ] && exit 0

read -r -d '' MSG <<EOF
You have called ${TOOL} ${COUNT} times in a row. If you are retrying the same
approach, stop now and pick one of these instead:

  1. Re-reason from the evidence you already have. Do not repeat an action on a
     hypothesis you have not tested.
  2. Route around it. If the environment is fighting you, change the code or the
     structure so the problem stops existing, rather than poking the environment
     again.
  3. Report what is blocking you and hand the decision back.

Continuing to retry is not on the list.
EOF

jq -n --arg msg "$MSG" '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:$msg}}'
exit 0
