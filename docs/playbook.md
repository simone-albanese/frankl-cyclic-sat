# A Playbook: Attacking Open Mathematical Problems with an AI Agent and a Laptop

*This document distills one complete campaign — deciding the rotation-invariant
case of Frankl's conjecture on 13–15 points with Claude Code on a 16 GB MacBook
— into a reusable base for the next open problem. It is deliberately a catalog
of** problems encountered**, each with the fix that worked, because the failures
generalize better than the successes. Everything quantitative below was
measured in this repository's logs; nothing is hypothetical unless labeled so.*

**The configuration this experience applies to:** one consumer machine (Apple
M4, 4 P-cores, 16 GB RAM, ~300 GB free disk), Claude Code as the agent runtime
(one pinned model, headless loop + interactive sessions), open-source exact
solvers (SAT/CP), no cluster, no cloud, budget-conscious token usage. Roughly:
what a motivated individual owns already.

---

## 1. The problem-selection problem (most campaigns are lost here)

An open problem is attackable in this configuration only if it can be shaped
into **finite, decidable instances with a ladder of sizes**. What made Frankl
workable, stated as requirements for the next problem:

- **A symmetry or restriction that collapses the search space.** All families
  on 13 points is beyond any computer (the raw search space is doubly
  exponential); *rotation-invariant* families collapse to 630 Boolean
  variables. Find the analogous move first — invariance, canonical forms, a
  proven WLOG reduction — or do not start. This is mathematics done *before*
  computation, and it is where the agent's reasoning genuinely contributed
  (orbit decomposition, integrality lemmas, the Cauchy upgrade from cyclic to
  all transitive groups).
- **A ladder with solved rungs.** Z7 and Z11 were theorems before we began
  (literature covers ≤ 12 points); they became *control instances*. A pipeline
  that cannot be tested against known answers cannot be trusted on unknown
  ones. If the problem has no solved small cases, manufacture some (brute
  force a miniature version).
- **Value in the negative outcome.** Here, UNSAT ("no counterexample of this
  shape") was itself a publishable statement. If only a positive hit counts
  (e.g. pure needle-in-haystack searches), a laptop campaign will most likely
  end with nothing to show.
- **A machine-checkable certificate, or two independent roads.** SAT gives
  DRAT certificates; CP/ILP verdicts can be cross-checked by an independent
  encoding. If a problem's computations cannot be independently verified,
  every result is one bug away from being noise.
- **Verdict arithmetic that fits integers.** The counterexample condition
  `2·maxfreq < |F|` never touches floating point. Reshape the target
  inequality until it is integer-exact, or accept a permanent source of doubt.

## 2. The resource walls, in the order they actually arrived

The naive expectation is "we will run out of CPU time." The campaign's actual
sequence of binding constraints was different, and knowing it in advance
changes how you plan:

1. **Context window (immediately).** No model session can hold a multi-day
   project. Solved architecturally, not heroically: fresh-context iterations,
   all state on files, a handoff contract (§4). This wall never bound again.
2. **RAM before CPU, and always the whole chain.** The historic machine
   OOM-killed the Z14 CP-SAT model at 3.94 GB before any time limit mattered.
   On the M4, Z15's *solve* fit comfortably (5.45 GB peak) — but the
   *verifier* was projected at 11–18 GB against 16 GB physical, and that,
   not time, is what ended the campaign. **Lesson: cost every stage of the
   chain — model build, solve, certificate size, verification RAM — before
   launching stage one.** The stage that kills you may be the last one.
3. **Disk as a rate, not a size.** The Z15 proof grew at a measured
   ~1.2 GiB/hour. Any run without a verdict-by date is also a disk timer:
   314 GB free ⇒ ~11 days of proof emission, full stop. Watch growth rates,
   not snapshots.
4. **Solver time is not a function of size.** Measured: Z13 15 s, Z14 37 min,
   Z15 (only 3.9× more clauses than Z14) still undecided after 12 h 56 m.
   Same encoder, same solver, same machine. Refutation difficulty is
   *qualitatively* discontinuous. Consequences: (a) never extrapolate solve
   times by size ratios — give intervals or refuse; (b) progress metrics lie
   (Z14 sat at 62% "variables remaining" for twelve minutes, then finished in
   0.3 s; Z15 sat at 50% for 3.6 hours and never finished); (c) when
   forecasting a running refutation, think in survival probabilities over a
   heavy-tailed distribution, not completion percentages.
5. **Token budget as a real resource.** ~160 iterations at maximum reasoning
   effort would have exhausted usage limits mid-campaign. The effort dial
   (§4) exists because model attention, like RAM, has a budget.

## 3. The trust problem (a lone agent will fool itself)

An unsupervised agent optimizes for reporting progress. The protocol must make
false progress *structurally impossible* to report:

- **Two independent methods for every claim.** Different formalisms (native
  integer constraint vs adder-circuit CNF), different codebases, ideally
  different failure modes. A shared bug must survive two uncorrelated
  implementations to slip through.
- **Certificates over authority.** Where the technology exists (SAT/DRAT),
  demand the proof artifact and verify it with an independent checker. Trust
  then rests on ~3k lines of checker plus a 60-line formula generator — not
  on a 100k-line solver, and not on the agent's word.
- **Controls before production, always.** Every pipeline, and every *change*
  to a pipeline, re-passes the known-answer instances first. This caught real
  encoding bugs during development at a cost of seconds.
- **Tripwires from theory.** Any frequency ratio below the proven 0.382 bound
  aborts everything: it cannot be a discovery, so it must be a bug. Find your
  problem's analogue — a quantity with a proven bound that computation must
  respect — and wire it as an assertion.
- **Audit-before-report.** A claim may be written to the journal only if
  backed by a tool result *in that same session*; negative outcomes verbatim.
  This single rule is most of why the diary is trustworthy.
- **Candidate ≠ result.** Anything found must pass two independent checkers
  before the word "success" appears anywhere. (Nothing ever passed, correctly.)

## 4. The architecture that held up (copy this)

Files, not memory. The complete kit is in this repository and is
problem-agnostic:

| piece | file | role |
|---|---|---|
| constitution | [CLAUDE.md](../CLAUDE.md) | non-negotiable rules, budgets, operating cycle |
| driver | [scripts/loop.sh](../scripts/loop.sh) | fresh headless session per atomic task; stops on DONE/BLOCKED/PAUSE/failures |
| handoff | `STATE/HANDOFF.md` | ≤ 60 lines, rewritten each iteration, sufficient for a cold restart |
| ledger | `STATE/backlog.md` | atomic tasks, value-per-cost order, one per iteration |
| diary | `STATE/journal.md` | append-only history |
| budgets | `STATE/hardware.env` | measured RAM/core/disk/timeout caps |
| guard | [scripts/watchdog.sh](../scripts/watchdog.sh) | kills any job exceeding RAM or deadline |
| effort dial | `STATE/effort.txt` | model reasoning effort per task class |
| owner monitor | `STATE/SITUAZIONE.md` + `.html` | plain-language status for a non-mathematician |
| lessons | `STATE/lezioni.md` | operational mistakes, one entry each, updated not duplicated |

Principles that made it work: **one atomic task per iteration** (resumable,
verifiable on files, within context budget); **~40% context ceiling** with
proxy signals (tool-call count, lines read) and a hard rule — at budget,
checkpoint and terminate, never start new work; **escalation is human-only**
(the loop may extend a timeout ×3 once on measured progress; every further
extension in the campaign was an explicit owner override, marked non-precedent);
**the filesystem is the memory — let the agent be brilliant only inside an
iteration.**

## 5. The operational traps (each cost real wall-clock here)

Environment and harness:

- **Interpreter identity.** Bare `python3` resolved to a system Python without
  the project's libraries — and reported the *same version* as the venv.
  Version strings prove nothing; only an import test does. Pin the interpreter
  path everywhere.
- **Silent permission paralysis.** In a not-yet-trusted workspace, Claude Code
  ignores the settings-file allowlist wholesale; the first loop run could
  execute nothing. Fix: pass permissions as CLI flags (`--allowedTools`).
  Never `--dangerously-skip-permissions`.
- **Config landmines.** A settings `env.PATH` *replaces* the inherited PATH
  (write it complete or system binaries vanish); BSD `sed` silently ignores
  GNU alternation (a filter "worked" while matching nothing — test every text
  filter on real output); never edit a running bash script in place (bash
  reads by byte offset — write-new + atomic `mv`).
- **Environment inheritance.** Launching the loop from inside another agent
  session leaked a dozen session variables into every child (one silently
  overrode the effort dial). The driver now scrubs its environment at startup.
- **Checker exit codes lie.** drat-trim's memory-exhaustion paths print a
  message and `exit(0)`. Grep for the literal success string (`s VERIFIED`),
  never trust exit codes alone. Assume other scientific tools do the same
  until proven otherwise.
- **Babysitting is the wrong use of a model.** Even throttled to one check
  every 10 minutes, surveillance of a 13-hour solve burned ~70 near-identical
  model sessions. Pure waiting belongs to `cron`/watchdogs; wake the agent on
  *events* (verdict, kill, threshold), not on schedule.

Process:

- **Read the driver's log before theorizing.** The permissions failure was
  diagnosed wrongly once by reasoning from symptoms while the correct cause
  sat verbatim in `loop.log`. Grep first, hypothesize second.
- **Heavy outputs never enter context.** `tail`/`grep -c`/`ls -l`, redirect
  everything else to log files. One accidental `cat` of a solver log can end
  an iteration's usefulness.
- **Interrupt with SIGTERM, not SIGKILL** — solvers flush statistics and
  close proof files cleanly, and those final statistics are data.
- **Know which log column is progress.** Conflicts and proof size grow
  monotonically and mean nothing; "variables remaining" was the only honest
  signal — and even it plateaus deceptively (§2.4). Identify your solver's
  least-lying metric before the long run, not during.

## 6. The endgame problem: stopping and publishing honestly

Two decisions ended this campaign well, and both generalize:

- **A feasibility analysis beats hope.** When the long run stalled, the
  useful artifact was not more patience but a read-only analysis separating
  measured from extrapolated: survival probability of the run (~10–15%),
  verifier RAM projection (11–18 GB > 16 GB), sharding cost envelope. It
  turned "should we keep waiting?" into an owner's decision with numbers.
  Write this analysis *before* emotional sunk-cost pressure builds; better,
  write the resource model before launching at all.
- **Unconfirmed results are published as unconfirmed.** Z15 had one solver's
  INFEASIBLE and no certificate — it is documented everywhere as *not
  decided to standard*, with the exact input (hash-pinned) so anyone can
  finish the job. The alternative — quietly claiming it — would have been
  cheaper and worthless. Honesty converted a failure into "open problem 1"
  with a costed plan attached.

Publication mechanics that mattered: certificates too big for git go to a
Release (compressed) *and* to Zenodo with a DOI; SHA-256 of both original and
compressed bytes recorded; deterministic generators mean the CNFs themselves
are reproducible ground truth; the working diary ships verbatim as primary
source.

## 7. What this configuration can and cannot reach (measured envelope)

For SAT-shaped attacks on this class of hardware (16 GB, 4 P-cores), the
campaign's data points draw the envelope:

| regime | measured anchor | verdict |
|---|---|---|
| ≤ ~2 M clauses | Z13: seconds | interactive play |
| ~7 M clauses | Z14: solve 37 min, verify 29 min, RSS ≤ 2.5 GB | comfortable, fully certifiable |
| ~29 M clauses | Z15: solve > 13 h unfinished; verification needs > 16 GB | at the wall; needs sharding or ≥ 32 GB |
| ~115 M clauses | Z16 (extrapolated) | out of reach monolithically: time, then disk |
| ~450 M clauses | Z17 (extrapolated) | out of reach: does not load |

The general rule extracted: **on consumer hardware the certifiable frontier is
roughly one ladder rung below the solvable frontier** — because verification
RAM ~ proof size, and proof size explodes precisely on the instances that are
barely solvable. Plan campaigns to end on a *certified* rung, with the next
rung's inputs published for better-equipped successors. Escape routes, in
order of preference: a stronger reduction (more mathematics), sharding into
2^k independent subproblems (correctness is a one-line argument; probe a
sample before committing — the runtime distribution is dominated by its tail),
a bigger-RAM machine for verification only, and only then more patience.

## 8. Checklist for the next open problem

1. **Reduce first.** Find the symmetry/WLOG move that makes instances finite
   and small. If none exists, pick a different problem.
2. **Build the ladder.** Identify solved rungs (controls) and the first open
   rung. Verify the literature actually covers the "solved" ones.
3. **Two encoders, two checkers, integer verdicts, a theory tripwire.** Write
   them before any production run; validate on controls end-to-end, including
   the certificate chain.
4. **Measure the machine; write the budgets** (`hardware.env`): RAM cap
   ~60% of physical, cores, timeout policy, disk floor.
5. **Probe before solving**: build the model of the first open rung, record
   RSS and clause counts, *project the full chain including verification*,
   and compare against budgets. If it does not fit, redesign (shard/encode),
   don't hope.
6. **Deploy the loop** (constitution + driver + state files, copied from
   here) and let it run the ladder bottom-up, one atomic task per iteration.
7. **Certify the highest rung you can; publish the next rung's inputs** with
   hashes, an honest status label, and a costed continuation plan.
8. **Archive**: repo + release for access, Zenodo for permanence, diary
   verbatim, lessons file updated for the campaign after this one.

---

*The one-sentence summary of everything above: the mathematics decides whether
the problem is attackable, the resource model decides whether the attack is
finishable, and the trust architecture decides whether the result is worth
anything — and all three must be settled before the long computation starts,
because none of them can be fixed while it runs.*
