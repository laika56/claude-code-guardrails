---
name: claude-guardrails
description: Install three Claude Code hooks that stop "done" being reported over failed commands — surfaces failure signals after Bash calls, makes verification replies state what was and was not checked, and breaks retry loops. Use when the user wants to install, check, or remove these guardrails.
---

# Claude Code Guardrails

Three bash hooks (bash + jq only, 58–69 lines each) that move three rules out of the
instructions file and into the moment they matter.

| Hook | Event | What it does |
|---|---|---|
| `verify-before-done.sh` | PostToolUse (Bash) | Scans the output for failure signals (non-zero exit, failing test counts, tracebacks, connection refused, permission denied) and adds a note naming what it found. Skips `cat`/`grep`/`head`/`--help` so reading a file about failures does not fire it. |
| `quantify-claims.sh` | UserPromptSubmit | On verification-shaped prompts, asks the reply to open with `verified n% (numerator/denominator)` and to name what was not checked. |
| `loop-breaker.sh` | PostToolUse | Counts consecutive calls to the same tool and, past a threshold, tells the agent to stop and choose a different move. Bash, Read, Grep, Glob, Edit, Write, TodoWrite and Task are skipped by default (`GUARDRAILS_LOOP_SKIP`) so ordinary work does not trip it. |

Why hooks: in one measured workspace the verification rule was in context for all 22
verification-shaped replies and was followed in 13 of them (59%).

## Install

When the user asks to install:

1. Check `jq` exists: `command -v jq`. If missing, tell the user to install it
   (`brew install jq` or their package manager) and stop.
2. Ask where: this project only (default, writes `<project>/.claude/`) or every project
   (`--global`, writes `~/.claude/`). Show the three files in `hooks/` and `install.sh`.
3. After the user agrees, run from this skill folder:
   `bash install.sh <project path>` or `bash install.sh --global`.
   It copies the hooks to `<root>/hooks/`, writes a timestamped
   `settings.json.bak.<YYYYmmddHHMMSS>` next to `settings.json`, then merges the entries.
   Running it again adds nothing new.
4. Verify: `jq '.hooks | keys' <root>/settings.json` includes `PostToolUse` and
   `UserPromptSubmit`.

## Check

`jq -r '.hooks[][].hooks[].command' <root>/settings.json | grep -cE 'verify-before-done|quantify-claims|loop-breaker'`
— 3 means all three are installed.

## Remove

Restore the newest `settings.json.bak.*` in `<root>/`, or delete the three entries whose
command ends in `verify-before-done.sh`, `quantify-claims.sh` or `loop-breaker.sh`.

## What this does not do

It does not make an agent honest or prevent every false completion. It makes failed output
hard to skip past. Nothing is sent anywhere; the hooks only read the hook payload on stdin.
