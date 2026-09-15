# Launch drafts — claude-guardrails

Drafts only. Nothing here has been posted.

**Rules followed:** every number below is measured, not estimated. No claim
appears here that is not already in `README.md`. Where a measurement comes from
a single workspace, it says so.

**Numbers available to cite**

| Claim | Value | Where it came from |
|---|---|---|
| Rule-in-context compliance without a hook | **13 of 22 (59%)** | one workspace, verification-shaped replies |
| Test cases the hooks passed | **8** | true positive, false positive, and reset paths |
| False positive fixed during testing | **1** | hook fired on `cat` of its own source |
| Size | **58–69 lines each, 191 total**, 3 hooks | `wc -l` 2026-09-14 |
| Dependencies | bash + jq | — |

**Do not claim:** that it makes an agent honest, that it prevents all false
completion, any revenue or user count, or any number not in the table above.

---

## Reddit — r/ClaudeAI

Norm: lead with the problem, not the product. Self-promo gets downvoted; a
post-mortem that happens to end in a repo does not.

### Title options

1. My agent kept reporting success over failed commands. I measured how often, then fixed it with hooks.
2. "Rule is in CLAUDE.md" and "rule gets followed" are not the same thing — 13/22
3. Three hooks that stop Claude Code from calling a failed command "done"

### Body

I had a rule in my project instructions: when I ask whether something was
checked, answer with a real number, not "mostly".

It was in context every single time. I went back and counted how often it was
actually followed: **13 out of 22** verification-shaped replies. 59%.

That reframed the problem for me. The rule was never missing. It just wasn't
being applied at the moment it mattered — the model composes a summary from its
own recollection of the turn, and recollection is exactly the unreliable part.

Hooks fire at the moment. So I moved three rules out of the instructions file
and into hooks:

**1. `verify-before-done`** — runs after every Bash call, scans output for
failure signals (non-zero exit, failing test counts, tracebacks, ECONNREFUSED,
permission denied) and injects what it found into context. The agent then can't
summarise the turn as done without addressing it. It doesn't block anything; it
makes the failure unskippable.

The obvious false positive bit me immediately: it fired on `cat` of its own
source, because the file *describes* failures. A hook that cries wolf gets
ignored, which is worse than no hook. So `cat`/`grep`/`head`/`--help` are
skipped now.

**2. `quantify-claims`** — fires on verification-shaped prompts and requires the
reply to open with `verified n% (numerator/denominator)`. State the denominator.
State how you cut it — the same log sliced two ways gave me 38% and 59%. Name
what you didn't look at.

**3. `loop-breaker`** — counts consecutive same-tool calls and interrupts the
retry spiral. Different tool resets the counter, so ordinary work never trips
it. My first version had no skip list and fired on a healthy code review at five
Bash calls; Read/Grep/Bash/Edit are excluded now.

Eight test cases, both directions — fires when it should, silent when it
shouldn't. The installer merges into your existing `settings.json` rather than
replacing it, backs up first, and is idempotent.

bash + jq, nothing else, nothing phones home. Each hook is 58–69 lines (191 total) —
short enough that you should read them before installing, and I'd rather you did.

https://github.com/laika56/claude-code-guardrails

Happy to hear where it misfires for you. The false-positive surface is the part
I'm least confident about.

---

## Hacker News — Show HN

Norm: plain, no marketing voice, no bold, no emoji. State what it does, how it
works, what it doesn't do. Answer questions in the thread.

### Title options

1. Show HN: Hooks that stop a coding agent from reporting success over a failed command
2. Show HN: Claude Code guardrails – make the agent show its denominator
3. Show HN: I measured how often my agent followed its own instructions (59%)

### Body

Three shell hooks for Claude Code.

The failure they address: a command exits non-zero, or a test suite reports
failures, and the agent writes "fixed, tests are passing now". The failure is in
the transcript. Nobody reads it.

I don't think this is a model being careless. It's structural — the summary is
composed from the agent's recollection of the turn, and that's the unreliable
part. Putting the rule in an instructions file doesn't fix it: I counted, and a
rule that was in context on all 22 verification-shaped replies was followed on
13 of them. Hooks fire at the moment instead of being available at the moment.

- verify-before-done: PostToolUse on Bash. Greps the output for failure signals
  and injects them into context. Doesn't block the call.
- quantify-claims: UserPromptSubmit. On verification-shaped prompts, requires
  the answer to open with a numerator and denominator, and to name what wasn't
  examined.
- loop-breaker: counts consecutive same-tool calls, interrupts past a threshold.
  A different tool resets it.

Both false-positive cases I hit are handled: the first hook fired on `cat` of a
file containing failure text, and the third fired on a legitimate review at five
Bash calls. Eight test cases cover both directions.

bash and jq. The installer merges into an existing settings.json, backs it up,
and is idempotent. 58–69 lines per hook, 191 total.

What it doesn't do: it can't make a determined model write an accurate summary.
It raises the cost of not doing so from zero to non-zero. In my use that has
been most of the fight, but it is not a guarantee and I'd rather say so.

---

## X

Norm: one idea per post. Numbers early. No thread padding.

### Option 1 — the measurement

> I had a rule in my agent's instructions: answer verification questions with a
> real number.
>
> It was in context every time.
>
> I counted how often it was actually followed: 13 of 22.
>
> Being in context ≠ being applied. Moved it to a hook instead.
>
> https://github.com/laika56/claude-code-guardrails

### Option 2 — the failure mode

> Your coding agent runs a command. It exits non-zero.
>
> It writes "fixed, tests passing now".
>
> Tests passed because the code never changed.
>
> Three hooks that make that unskippable: https://github.com/laika56/claude-code-guardrails

### Option 3 — the false positive

> Wrote a hook to catch my agent calling failures "done".
>
> First thing it did was fire on `cat` of its own source — the file *describes*
> failures.
>
> A hook that cries wolf gets ignored, which is worse than no hook. Fixed, then
> shipped.
>
> https://github.com/laika56/claude-code-guardrails

---

## Sequencing

**HN first** (revised 2026-09-14). The original plan was Reddit first, but the
posting account has karma 1 — large subreddits filter that out, so the Reddit
thread would surface nothing. Show HN gets one shot; run the correctness
self-check (the "do not claim" list above) before posting instead of relying
on a Reddit thread to catch it. X second, same day is fine for X only. Reddit
last, after 2–3 weeks of karma from ordinary replies.

Do not post the same day to more than one. Cross-posting within hours reads as
a campaign and gets treated as one.
