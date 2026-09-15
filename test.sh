#!/usr/bin/env bash
# test.sh - the eight cases in the README's "Verified" table, run for real.
#
#   ./test.sh
#
# Both directions matter. A hook that only proves it fires is half a test: the
# expensive failure is the one that cries wolf, gets ignored, and takes the real
# warnings down with it. Four of these eight assert silence.
#
# No framework. Each case pipes a hook the JSON shape Claude Code sends it and
# checks whether additionalContext came back.

set -uo pipefail
cd "$(dirname "$0")"

command -v jq >/dev/null || { echo "jq is required. brew install jq"; exit 1; }

PASS=0; FAIL=0
STATE_DIR="${TMPDIR:-/tmp}/claude-guardrails"

# want is "fires" (hook emitted additionalContext) or "silent" (it did not).
run() {
  local name="$1" hook="$2" want="$3" input="$4" out got
  out=$(printf '%s' "$input" | bash "hooks/$hook" 2>/dev/null)
  if printf '%s' "$out" | grep -q 'additionalContext'; then got=fires; else got=silent; fi
  if [ "$got" = "$want" ]; then
    PASS=$((PASS + 1)); printf '  ok    %-44s %s\n' "$name" "$got"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL  %-44s want %s, got %s\n' "$name" "$want" "$got"
  fi
}

check() { # for cases that are not a hook invocation
  local name="$1" ok="$2"
  if [ "$ok" = "yes" ]; then
    PASS=$((PASS + 1)); printf '  ok    %-44s %s\n' "$name" "as claimed"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL  %-44s %s\n' "$name" "not as claimed"
  fi
}

bash_event() { jq -nc --arg c "$1" --arg o "$2" \
  '{tool_name:"Bash", tool_input:{command:$c}, tool_response:{stdout:$o, stderr:""}}'; }
loop_event() { jq -nc --arg t "$1" --arg s "$2" '{tool_name:$t, session_id:$s}'; }

echo "verify-before-done"
run "Bash output contains failing tests" verify-before-done.sh fires \
  "$(bash_event 'npm test' '3 tests failed
exit code 1')"
# Test runners print "failed: 0" on a green run. Only a non-zero count counts.
run "Bash output is a clean pass (fail 0)" verify-before-done.sh silent \
  "$(bash_event 'pytest' '55 passed, failed: 0 in 2.10s')"
# The regression that made this hook usable: reading a file ABOUT failures is
# not a failure. Without the reader-command skip it fired on cat of its own source.
run "cat of a file describing failures" verify-before-done.sh silent \
  "$(bash_event 'cat notes.md' 'we used to see exit code 1 here, now fixed')"

echo "quantify-claims"
run "verification-shaped prompt" quantify-claims.sh fires \
  '{"prompt":"did you check all of the files?"}'
run "ordinary feature request" quantify-claims.sh silent \
  '{"prompt":"add a dark mode toggle to the settings page"}'

echo "loop-breaker"
export GUARDRAILS_LOOP_THRESHOLD=5
rm -f "$STATE_DIR"/testsess.*.loop 2>/dev/null
# WebFetch is not in SKIP_TOOLS, so five in a row must trip it.
for _ in 1 2 3 4; do printf '%s' "$(loop_event WebFetch testsess.a)" | bash hooks/loop-breaker.sh >/dev/null 2>&1; done
run "5th consecutive same-tool call" loop-breaker.sh fires "$(loop_event WebFetch testsess.a)"
# A different tool in between must reset the counter, so the next call is quiet.
for _ in 1 2 3 4; do printf '%s' "$(loop_event WebFetch testsess.b)" | bash hooks/loop-breaker.sh >/dev/null 2>&1; done
printf '%s' "$(loop_event WebSearch testsess.b)" | bash hooks/loop-breaker.sh >/dev/null 2>&1
run "a different tool in between resets" loop-breaker.sh silent "$(loop_event WebFetch testsess.b)"
rm -f "$STATE_DIR"/testsess.*.loop 2>/dev/null

echo "install.sh"
# Idempotency: installing twice must not duplicate the hook entries, and an
# existing unrelated hook must survive the merge.
TMP=$(mktemp -d)
mkdir -p "$TMP/.claude"
cat > "$TMP/.claude/settings.json" <<'JSON'
{"hooks":{"PostToolUse":[{"matcher":"","hooks":[{"type":"command","command":"/existing/mine.sh"}]}]}}
JSON
./install.sh "$TMP" >/dev/null 2>&1
./install.sh "$TMP" >/dev/null 2>&1
DUPES=$(jq '[.hooks[][]?.hooks[]?.command] | group_by(.) | map(select(length > 1)) | length' "$TMP/.claude/settings.json" 2>/dev/null)
KEPT=$(jq '[.hooks[][]?.hooks[]?.command] | index("/existing/mine.sh") != null' "$TMP/.claude/settings.json" 2>/dev/null)
[ "$DUPES" = "0" ] && [ "$KEPT" = "true" ] && check "installer run twice, no duplicates" yes || check "installer run twice, no duplicates" no
rm -rf "$TMP"

echo
echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
