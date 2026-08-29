#!/usr/bin/env bash
# Install the guardrail hooks into a Claude Code project.
#
#   ./install.sh              # install into the current directory's project
#   ./install.sh /path/to/repo
#   ./install.sh --global     # install into ~/.claude (all projects)
#
# Merges into an existing settings.json instead of replacing it. Backs up first.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="${1:-$PWD}"
if [ "$TARGET" = "--global" ]; then
  ROOT="$HOME/.claude"
else
  ROOT="$TARGET/.claude"
fi

command -v jq >/dev/null || { echo "jq is required. brew install jq"; exit 1; }

HOOK_DIR="$ROOT/hooks"
SETTINGS="$ROOT/settings.json"
mkdir -p "$HOOK_DIR"

for h in verify-before-done quantify-claims loop-breaker; do
  cp "$SRC/hooks/$h.sh" "$HOOK_DIR/$h.sh"
  chmod +x "$HOOK_DIR/$h.sh"
  echo "  installed  $HOOK_DIR/$h.sh"
done

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"

# Merge, do not replace. Existing hooks on the same events are preserved; ours
# are appended. Re-running the installer does not duplicate entries.
jq --arg dir "$HOOK_DIR" '
  def add($event; $matcher; $cmd):
    .hooks[$event] = (
      (.hooks[$event] // [])
      | if any(.[]?.hooks[]?.command? // ""; . == $cmd) then .
        else . + [ { matcher: $matcher, hooks: [ { type: "command", command: $cmd } ] } ]
        end
    );
  .hooks = (.hooks // {})
  | add("PostToolUse";     "Bash"; $dir + "/verify-before-done.sh")
  | add("UserPromptSubmit"; "";    $dir + "/quantify-claims.sh")
  | add("PostToolUse";     "";     $dir + "/loop-breaker.sh")
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

echo
echo "  settings   $SETTINGS  (backup written alongside)"
jq -e '.hooks | keys' "$SETTINGS" >/dev/null && echo "  json ok"
echo
echo "Restart Claude Code, or open /hooks once, to load them."
