#!/usr/bin/env bash
# quantify-claims — make the agent show its denominator.
#
# The failure this prevents:
#   You ask "did you check all of it?" and get back "yes, mostly" or "I reviewed
#   the codebase". Those are not answers. They are guesses wearing the costume of
#   an answer, and you cannot tell which parts were actually read.
#
#   Measured on one workspace: with the rule written in a project instructions
#   file and nothing else, compliance was 13 of 22 verification-shaped replies
#   (59%). The rule was in context every single time. Being in context is not
#   the same as being followed. Injecting it at the moment of the request is
#   what closed the gap.
#
# How it works:
#   Runs on UserPromptSubmit. If the prompt looks like a verification question,
#   it injects the answer format. Fires on the request, not on the reply, so the
#   requirement is present while the answer is being composed.

set -uo pipefail

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
[ -z "$PROMPT" ] && exit 0

# Verification-shaped requests. Deliberately broad: a false positive costs a few
# hundred tokens, a false negative costs a wrong answer you believe.
PATTERN='did you|have you|are you sure|is it (done|fixed|working)|all of (it|them)|everything|how (much|many|far)|check(ed)?|verif|confirm|complete|coverage|how much is left|what.s left'

printf '%s' "$PROMPT" | grep -qiE "$PATTERN" || exit 0

read -r -d '' MSG <<'EOF'
This is a verification question. Open your reply with this line, before anything
else — before any preamble, model note, or summary:

    verified n% (numerator/denominator) - no guessing

Rules for that line:
  - State the denominator. A bare "100%" is void. Write what you counted:
    "100% (6/6 files)", "8.8% (39,544B / 450,441B)".
  - State how you cut the denominator. The cut changes the answer - the same
    log sliced two ways gave 38% and 59%.
  - Count. Do not round a guess into a percentage; that is a guess in a
    costume, which is worse than an admitted guess.
  - If it cannot be counted, write "not countable" and why.
  - Name what you did NOT look at, and the limit of your coverage. If you
    grepped 13 keywords, say the other keywords are unchecked.
  - Numbers you got from someone or something else: label them as reported,
    not measured. Do not mix them with your own counts.
  - "It can't be done" is also a claim that needs verification. Check a second
    path before asserting a limitation.

The words "verified" or "confirmed" alone are NOT the marker. A claim without a
denominator is the exact evasion this check exists to catch.
EOF

jq -n --arg msg "$MSG" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$msg}}'
exit 0
