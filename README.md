# Claude Code Guardrails

Three hooks that stop your coding agent from telling you it did something it did not do.

---

## The problem

Your agent runs a command. It exits non-zero. The agent writes *"Fixed — tests are passing now."*

The failure is right there in the transcript. Nobody reads it. You find out three commits later.

This is not a model being dumb. It is a **structural** gap: the agent summarises a turn from
its own recollection of the turn, and recollection is exactly the thing that is unreliable.
Rules in `CLAUDE.md` do not close it, because a rule that is *in context* is not a rule that is
*applied at the moment it matters*.

Measured on one workspace: with the verification rule written in the project instructions and
nothing else, the agent followed it in **13 of 22** verification-shaped replies — **59%**. The
rule was in context all 22 times.

Hooks fire at the moment. That is the whole difference.

---

## What you get

### `verify-before-done.sh` — the agent cannot call a failure a success

Runs after every Bash call. Scans the output for failure signals — non-zero exits, failing test
counts, tracebacks, `ECONNREFUSED`, permission denials — and injects a note naming what it found.
The agent then cannot summarise the turn as done without addressing it.

It does **not** block the command. It makes the failure impossible to walk past.

Includes the fix for the obvious false positive: reading a file that *describes* failures
(`cat`, `grep`, `--help`) is not a failure. A hook that cries wolf gets ignored, and an ignored
hook is worse than none.

### `quantify-claims.sh` — "did you check all of it?" gets a real answer

Fires on verification-shaped prompts. Requires the reply to open with:

```
verified n% (numerator/denominator) - no guessing
```

and enforces the parts that actually matter:

- **State the denominator.** A bare "100%" is void.
- **State how the denominator was cut.** The cut changes the answer — the same log sliced two
  ways produced 38% and 59%.
- **Count, don't round.** A guess formatted as a percentage is worse than an admitted guess,
  because it looks like evidence.
- **Name what was not looked at.** Grepped 13 keywords? Say the rest is unchecked.
- **Label reported numbers as reported**, not measured.
- **"It can't be done" is a claim too** — check a second path before asserting a limitation.

### `loop-breaker.sh` — stop the retry spiral

Counts consecutive calls to the same tool. Past the threshold (default 5) it tells the agent to
stop and pick a different move: re-reason from evidence, route around the problem, or hand the
decision back.

Using a different tool resets the counter, so ordinary work never trips it. `Bash`, `Read`,
`Grep`, `Edit` and friends are skipped by default — a run of those is investigation, not a loop.
An earlier version without that skip list fired on a healthy code review at five Bash calls.

Tune with `GUARDRAILS_LOOP_THRESHOLD` and `GUARDRAILS_LOOP_SKIP`. Prefer adding a tool to the
skip list over raising the threshold — a higher threshold hides real loops too.

---

## Install

Requires `jq`, and Claude Code.

```bash
./install.sh                 # this project
./install.sh /path/to/repo   # a specific project
./install.sh --global        # ~/.claude, all projects
```

The installer **merges** into your existing `settings.json` — your permissions and your own hooks
are preserved — writes a timestamped backup first, and is idempotent. Running it twice does not
duplicate entries.

Then restart Claude Code, or open `/hooks` once, so the config reloads.

### Verify it took

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":{"stdout":"3 tests failed"}}' \
  | .claude/hooks/verify-before-done.sh
```

You should get a JSON object back. Silence means it is not wired up.

---

## Uninstall

```bash
rm .claude/hooks/{verify-before-done,quantify-claims,loop-breaker}.sh
```

and remove the three entries from `.claude/hooks` in `settings.json`, or restore the backup the
installer left next to it.

---

## Verified

Eight cases, both directions — a guard that only fires is as useless as one that
never does. Run them yourself:

```
./test.sh
```

| Case | Expected | Result |
|---|---|---|
| Bash output contains failing tests | fires | ✅ |
| Bash output is a clean pass (`fail 0`) | silent | ✅ |
| `cat` of a file *describing* failures | silent | ✅ |
| Verification-shaped prompt | fires | ✅ |
| Ordinary feature request | silent | ✅ |
| 5th consecutive same-tool call | fires | ✅ |
| A different tool in between | counter resets | ✅ |
| Installer run twice | no duplicate entries | ✅ |

The table is the test file, in order. Four of the eight assert *silence*: the
first hook used to fire on `cat` of its own source, and an early loop-breaker
fired on a healthy review at five Bash calls. A hook that cries wolf gets
ignored, which is worse than no hook, so both regressions have a case here.

The installer case runs the real installer twice against a `settings.json` that
already contains an unrelated hook, then asserts no duplicate commands and that
the pre-existing hook survived.

## What this is not

- **Not a linter.** It governs what the agent *claims*, not what your code looks like.
- **Not a blocker.** Nothing here stops a tool call. Everything here makes a fact unskippable.
- **Not magic.** A determined model can still write a bad summary. These raise the cost of doing
  it from zero to non-zero, which in practice is most of the fight.

## Scope

Written for Claude Code's hook system (`PostToolUse`, `UserPromptSubmit`) on macOS and Linux.
Plain `bash` + `jq`, no other dependencies, nothing phones home. Read them — they are under
70 lines each (191 total), and you should not install hooks you have not read.

## Related

- The measurement behind this repo, written up: [Your coding agent said the tests pass. The command exited 1.](https://repro-log.blogspot.com/2026/09/your-coding-agent-said-tests-pass.html)
- Same hooks as a zip with the installer, plus email support if it misfires on your setup: [$15 on Gumroad](https://quietfail.gumroad.com/l/claude-code-guardrails). The code here is the whole product; pay only if the support is worth it to you.
- A sibling harness for *unattended* runs (catches "exit 0 with zero changed files", edits outside scope, half-finished work reported as done): [agent-delegate](https://quietfail.gumroad.com/l/agent-delegate).

## License

MIT. Use them, change them, ship them inside your own tooling.
