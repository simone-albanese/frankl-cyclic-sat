# How an AI Loop Ran This Project

*This repository is also an experiment in research methodology: every
computation in it was planned, launched, monitored, logged and written up by an
AI agent (Claude) operating in an autonomous loop, under a written constitution
and hard resource budgets, with a human owner who set goals and made a handful
of documented override decisions. This page describes the machinery honestly —
including what it got wrong — because the workflow is as reproducible as the
mathematics.*

The primary sources are preserved verbatim (in Italian):
[CLAUDE.md](../CLAUDE.md) (the constitution),
[STATE/journal.md](../STATE/journal.md) (the diary: 1,297 lines),
[STATE/lezioni.md](../STATE/lezioni.md) (lessons learned),
[STATE/backlog.md](../STATE/backlog.md) (the task ledger),
[STATE/HANDOFF.md](../STATE/HANDOFF.md) (the final handoff).

## The architecture: amnesia by design

The core problem of long-running agentic work is context: a session that
remembers everything eventually drowns in its own history. This project
inverted the difficulty into a design principle:

- **The outer loop** ([scripts/loop.sh](../scripts/loop.sh)) runs up to 200
  iterations. Each iteration starts a **fresh CLI session with empty context**
  and one fixed instruction: *read the constitution and the handoff, execute
  exactly one atomic task, terminate.* The loop stops by itself on `DONE`,
  `BLOCKED`, or four consecutive command failures.
- **All state lives in files.** If a fact is not written in `STATE/` or
  `results/`, it does not exist for the next iteration. No session-to-session
  memory, no implicit knowledge.
- **The handoff** (`STATE/HANDOFF.md`, rewritten from scratch every iteration,
  ≤ 60 lines) must alone suffice for a cold restart: objective, position, last
  outcome, *the exact next commands ready to paste*, live background PIDs,
  known traps.
- **The journal** is append-only history; the **backlog** holds atomic tasks
  ordered by value-per-cost; `status.txt` is a one-word semaphore
  (`RUN`/`DONE`/`BLOCKED`).

Between 13:31 on 11 Aug and 09:58 on 12 Aug 2026 the loop executed ~158
numbered iterations this way — bootstrap, validation, Z13 re-verification, the
whole certified Z14 chain, the Z15 attempt, and dozens of surveillance rounds
over the long runs.

## Resource governance (the part that kept a laptop safe)

A 16 GB laptop running unattended solver jobs for 13 hours needs guardrails,
not optimism:

- **Budgets measured at bootstrap** into `STATE/hardware.env`: 9 GB RAM per
  job (60% of physical), 3 cores, 20-minute default timeout with a single ×3
  escalation allowed only on measured progress.
- **Every heavy job** runs `nice -n 10`, under `caffeinate -i`, in background
  with output redirected, guarded by
  [scripts/watchdog.sh](../scripts/watchdog.sh) — a 20-line shell loop that
  kills on RAM or deadline overrun and stamps `KILL RAM`/`KILL TIMEOUT` into
  the job log.
- **Context budget**: each iteration must stay under ~40% of the model's
  context window, tracked by proxy signals (number of tool calls, lines read,
  presence of a long output). At budget: checkpoint, hand off, terminate. Long
  logs are never `cat`-ed; only `tail`/`grep` excerpts enter a session.
- **Effort dial**: `STATE/effort.txt` sets the model's reasoning effort per
  task class — high for design tasks, medium for surveillance rounds — because
  200 iterations at maximum effort would burn the token budget on
  administrative babysitting.

## Rigor rules (the part that kept the mathematics safe)

The constitution encodes the skepticism a lone unsupervised agent needs:

- **Nothing is a SUCCESS until verified by an independent method** — second
  solver, second checker, or verified certificate. "A success not yet verified
  is only a candidate."
- **Audit before reporting**: every progress claim written to the journal or
  handoff must be backed by a tool result *from that session*; negative
  outcomes are reported with their output, unembellished.
- **Controls before production**: no pipeline's verdict counts until it
  reproduces known theorems (Z7, Z11, the tight power-set instance).
- **Integer-only verdicts**; a frequency ratio below the proven 0.382 bound
  anywhere is treated as a bug, halting everything.
- **One atomic task per iteration; no scope creep**: no refactors, no
  unrequested extras; stop-and-ask (`BLOCKED`) is reserved for genuinely
  human decisions.

Result: across ~158 iterations, the loop never declared a false success, never
lost a background run, and never had to be restored from a corrupted state.

## The human in the loop (four decisions, all logged)

The owner — deliberately, not a mathematician — supervised through
`STATE/SITUAZIONE.md`, a plain-language status page the loop rewrote every
iteration (traffic-light semaphore, one-sentence summary, "does anything need
you?"), plus macOS notifications on milestones. Human interventions, all
recorded in the backlog/journal:

1. Approving continuation from Z14 (already `DONE` by the goal's criteria) to
   Z15.
2. Two deadline extensions for the Z15 run (to 12 h, then 15 h), explicitly
   marked as owner overrides that the loop must not treat as precedent.
3. The final call, on the morning of 12 Aug: a read-only feasibility analysis
   (measured-versus-extrapolated, the same discipline as everything else here;
   its conclusions are preserved in
   [open-problems.md](open-problems.md#the-feasibility-analysis)) put the
   probability of an in-budget verdict at ~10–15% and the certificate
   verification beyond the machine's RAM. The owner chose to stop cleanly and
   publish. The stop itself was orderly: SIGTERM to loop, watchdog, and
   solver, whose final statistics are flushed at the tail of
   `results/logs/T9b_cadical_z15.log`.

## What it got wrong (kept, because this is data too)

[STATE/lezioni.md](../STATE/lezioni.md) preserves every operational lesson at
the moment it was paid for. Highlights, translated:

- **The interpreter trap**: bare `python3` resolved to a system Python without
  the project's libraries; version checks lie (same minor version), only an
  import test proves the environment. Rule: always the venv binary, explicitly.
- **Silent permission failure**: in an untrusted workspace the CLI ignored the
  settings-file allowlist wholesale; the first diagnosis (blame the rule
  syntax) was wrong, and the correct one was sitting verbatim in the driver
  log. Lesson enshrined: *grep the log before theorizing.* Fix: pass
  permissions as CLI flags.
- **Config landmines**: the settings `env` block replaces instead of extending
  (an incomplete `PATH` killed system hooks); BSD `sed` silently ignores GNU
  alternation (a filter "worked" while matching nothing); editing a running
  bash script corrupts its execution (bash reads by byte offset — replace via
  write-new + atomic `mv`, never in place).
- **Environment inheritance**: launching the loop from inside another agent
  session contaminated child sessions with a dozen inherited variables
  (including one that silently overrode the per-task effort dial). Fix: the
  driver scrubs its environment at startup.
- **Surveillance cadence**: the loop babysat a 13-hour solver with a fresh
  ~10-minute check-in session, ~70 nearly identical journal entries. Honest
  verdict: a cron job with a one-line liveness check would have done this for
  free; fresh-context iterations are the wrong tool for pure waiting.
- **Forecasting refutations**: the project's own logs show why time estimates
  kept failing — Z14 sat at 62% remaining variables for twelve minutes and
  then finished in 0.3 s. CDCL refutation is not a progress bar. The final
  feasibility analysis therefore modeled survival probabilities instead of
  completion times.

Token/cost accounting was not systematically tracked; treat the iteration
count (~158) and wall time (~20.5 h of loop operation) as the honest usage
metrics available.

## Could you run this yourself?

Yes — the constitution is model-agnostic in spirit: a driver that restarts a
fresh session per task, a handoff file contract, measured resource budgets, an
OS watchdog, and non-negotiable verification rules. Point it at a different
conjecture with a decidable finite structure and a pair of independent
checkers, and the same machinery applies. The one transferable core lesson:
**let the agent be brilliant inside an iteration, and let the filesystem — not
the agent — be the memory.**
