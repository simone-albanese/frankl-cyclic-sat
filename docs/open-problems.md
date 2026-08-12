# Open Problems, Costed

*A frontier is only useful if you know the price of crossing it. This page
lists what remains open, ranked roughly by value-per-effort, and attaches to
each problem the measured data and honest cost estimates from this project's
feasibility analysis. Measured numbers are marked **[M]**; extrapolations are
marked **[E]** together with the datum they extrapolate from. SAT refutation
times are* not *a smooth function of instance size — treat every time estimate
as an interval, never a point.*

---

## The feasibility analysis

(Read this first; problems 1–3 lean on it. Conducted 12 Aug 2026, read-only,
on the live Z15 run; the decision it motivated — stop and publish — is
recorded in [results/Z15-PARTIAL.md](../results/Z15-PARTIAL.md).)

**What was measured on the M4 (16 GB) [M]:**

- Z14 solve: 2,240 s; Z14 proof: 2.24 GB text-DRAT; Z14 verification: 1,736 s
  at RSS ≤ 1.70 GB, 3.41 M core lemmas, 315 M resolution steps.
- Z15 solve attempt: no verdict in 46,474 s; 63.0 M conflicts; max RSS 5.45 GB;
  binary-DRAT growth ≈ 1.2 GiB/hour, 11.87 GiB at stop.
- Z15 trajectory: remaining variables 75% until hour 8, 51% by hour 9.4, then
  flat at 50% for 3.6 h. (Z14, for contrast, collapsed 62% → verdict in its
  final 12 minutes — CDCL refutations end without warning.)
- CP-SAT: Z13 15.1 s → Z14 ~60 s → Z15 889 s (×4–15 per step).

**What was extrapolated [E], and from what:**

- *Verifier memory.* drat-trim holds proof + watch lists in RAM and never
  frees deleted lemmas. Two independent estimates for a completed Z15 proof
  (~14 GiB binary at the observed growth rate): (a) linear scaling of the
  measured Z14 RSS/proof ratio; (b) a lemma-count model from drat-trim's
  source (4 bytes/literal + 4-int header/lemma + 8-byte watch entries),
  calibrated within 30% on the measured Z14 run. Both land in
  **11–18 GB, central 13–15 GB** — above the project's 9 GB job cap and at or
  above the machine's 16 GB physical RAM. With swap, runtime becomes
  unpredictable (3–10× is typical). **This, not solver time, is what stopped
  the project.**
- *Verifier time*, if RAM sufficed: 2.5–5 h (from Z14's ≈ 756 s per GiB of
  text proof, adjusted for format density).
- *Chance the stopped run was near a verdict:* a heavy-tailed (Pareto-type)
  survival model over the run's age gave ~10–25% within the next 2.5 h,
  discounted to **~10–15%** because the run was sitting on its *second* long
  plateau. Genuinely uncertain — refutation could have landed in the next
  minute or the next week.

---

## Problem 1 — Confirm $\mathbb{Z}_{15}$ (the most valuable next step)

**Status:** CP-SAT says INFEASIBLE [M]; no independent confirmation, no
certificate. One of the following closes it.

**Route A — sharding (fits ordinary machines).** Pick $k$ orbits (take the
$k$ smallest-size, most-negative-coefficient ones); for each of the $2^k$
assignments of those orbits, decide the CNF with $k$ unit clauses appended.
The subproblems partition the search space, so **global UNSAT ⟺ all $2^k$
shards UNSAT** — the correctness argument is one line, which is the beauty of
it. Each shard can also emit its own (small) DRAT certificate, giving a fully
certified result as a conjunction.

- Shard counts: $k=8$ → 256, $k=10$ → 1,024, $k=12$ → 4,096.
- **The per-shard cost is unknown** — no shard has ever been run [M: absence].
  Do not trust anyone's average: cube-and-conquer runtimes are wildly skewed
  (most shards die in seconds; the total is dominated by a few hard ones).
- **Probe first** (this project's "smart, not harder" rule): generate $k=8$,
  run 4–8 extreme shards (all-excluded, all-included, a few mixed) with a
  30-minute cap each — ~2–4 h total [E]. If the median is minutes, proceed;
  if any probe shard stalls like the monolith, the road is encoding, not time.
- Disk discipline: each shard CNF is the 492 MB base + $k$ unit clauses —
  generate-and-delete one at a time (256 materialized copies = 126 GB;
  don't).
- Wall-clock envelope on an M4-class machine (3 concurrent shards ≈ 7.5 GB
  RAM): $k=8$ at a Z14-like 37 min/shard average → ≈ 2.2 days [E]; but see
  the skew warning — the tail governs, and the probe is what prices it.

**Route B — brute RAM (fits one big machine).** On ≥ 32 GB: rerun
`cadical results/z15min3.cnf z15.drat` to completion (unbounded; > 13 h [M]),
then drat-trim (est. 11–18 GB RAM, 2.5–5 h [E]). Mechanical, boring,
publishable.

**Route C — a second certificate-free method.** Any independent exact solver
agreeing with CP-SAT (a native pseudo-Boolean solver, an ILP solver with exact
arithmetic, a different CNF encoding) meets this project's two-method
standard, even without a DRAT.

The input formula is pinned: `dump_dimacs.py 15 z15min3.cnf 3`, sha256
`e6c732cf30bc619dd4c2706734bdcc2ed99255a422c52c4a8525563785115120`.

## Problem 2 — Better margin encodings

The binary-adder pseudo-Boolean encoding propagates weakly (measured on Z14†:
the pysat route stalled where CP-SAT's native constraint finished). Candidates:
totalizer/sequential-counter encodings, native PB solvers (RoundingSat-class),
or hybrid approaches. **Validation bar:** any new encoding must reproduce
UNSAT + VERIFIED on Z7/Z11 and re-derive Z13/Z14 before its word on Z15+
counts. A cautionary tale is included free of charge: lazy closure (CEGAR)
made refutation *harder*, not easier ([results.md §4](results.md#4-negative-and-cautionary-findings-kept-because-they-cost-real-hours)).

## Problem 3 — $\mathbb{Z}_{16}$ and $\mathbb{Z}_{17}$ (know the wall before you charge it)

Orbit counts are exact [M-grade arithmetic]: **4,114** and **7,710**. Everything
else is extrapolation from the measured 13→14→15 growth (clauses ×3.9 per
step) [E]:

| | $\mathbb{Z}_{16}$ [E] | $\mathbb{Z}_{17}$ [E] |
|---|---|---|
| closure clauses | ~110–120 M | ~430–470 M |
| CNF file | ~2.2 GB | ~9 GB |
| CP-SAT model RSS | ~9–10 GB (at the cap) | ~35–40 GB — **does not fit 16 GB** |
| CaDiCaL RSS | ~9–11 GB | ~35–45 GB — **does not load** |
| solve time | weeks-to-months lower bound (≥ 24× a value already unmeasured) | moot |
| proof volume | at the measured 1.2 GiB/h: **fills 314 GB of disk in ~11 days** | moot |

Verdict: **Z17 breaks immediately on RAM; Z16 breaks on time, then disk,** on
this class of hardware — monolithically. A sharded Z16 on a well-resourced
machine is speculative but not absurd *after* Z15's sharding data exists.
Also note $16 = 2^4$: the period structure (orbits of periods 1, 2, 4, 8, 16)
makes Z16 the first case where period-2 and period-4 orbits are plentiful —
worth a fresh look at reductions before brute force.

## Problem 4 — Transitive groups without long cycles (the mathematician's one)

On 13 points, Cauchy's theorem upgraded the cyclic result to *all* transitive
groups ([mathematics.md §6](mathematics.md#6-the-cauchy-corollary-why-13-is-special)).
On 14–16 points this fails: there exist transitive groups with no long cycle —
e.g. $\mathrm{PSL}(2,13)$ on 14 points (element orders 1, 2, 3, 6, 7, 13).
The problem: enumerate the transitive groups on 14, 15, 16 points that contain
no $m$-cycle (the transitive-group census is in GAP/Magma), and decide the
invariant-family question for the smallest ones. Invariance under a *larger*
group means *fewer* orbits, hence **smaller** SAT instances than the cyclic
case — this is computationally cheap; the work is the group-theoretic
bookkeeping. Success: "no transitive-invariant counterexample on 14 points"
full stop, extending the Z13-style blanket statement beyond primes.

## Problem 5 — Verified verification

drat-trim is trusted-but-unverified C. Re-checking the Z13/Z14 certificates
with a formally verified checker (cake_lpr, or the GRAT toolchain) would
shrink the trusted computing base to the 60-line formula generator. Mostly an
exercise in toolchain plumbing (DRAT → LRAT conversion), with a real payoff in
credibility. Warning from experience: drat-trim's memory-out paths exit with
code 0 — grep for `s VERIFIED`, never trust exit codes.

## Problem 6 — Publish the heavy artifacts

The 2.24 GB Z14 certificate (and a regenerated Z13 pair) deserve a permanent
DOI'd home (Zenodo: free, 50 GB/dataset). Compressed with `xz` or drat-trim's
bundled `compress`, the Z14 proof should also fit a GitHub Release asset
(< 2 GiB). Zero mathematics, real archival value.

## Problem 7 — Local search with a better landscape (low expected value, kept honest)

[anneal.py](../anneal.py) converges to the power set from every start [M].
Orbit-space moves with surrogate objectives (mean set size vs $m/2$) might
explore differently — but a heuristic can only ever *find* counterexamples,
never certify absence, and the certified results above say there is nothing to
find below 16 points. Try it for fun, not for glory.

---

*Whatever you attempt: run the [validation gauntlet](reproducing.md#2-the-validation-gauntlet-mandatory-before-believing-anything)
first, keep verdict arithmetic on integers, and treat any frequency ratio
below 0.382 as a bug in your code, because it is. Open an issue with measured
numbers — this repository's currency.*
