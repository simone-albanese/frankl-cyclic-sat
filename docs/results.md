# The Results, With Full Provenance

*Every claim in this project reduces to a number in a log file in this
repository. This document walks through the results in the order they were
obtained and, for each, records: what was run, on what, for how long, with what
memory, producing which artifact, verified how. Measured values are stated as
measured; the few extrapolations are labeled as such.*

**Machines.**
- **M4** — MacBook, Apple M4 (4 performance + 6 efficiency cores), 16 GB RAM,
  macOS 15.6.1. All runs dated 11–12 Aug 2026. Resource budgets enforced by an
  OS watchdog: 9 GB RAM per job, jobs at `nice -n 10` under `caffeinate -i`.
- **Historic machine** — the first session's machine (10 Aug 2026), measured
  ≈ 4.8× slower on the identical CP-SAT Z13 instance (72 s vs 15.1 s). Times
  from it are marked †.

**Toolchain (exact provenance).**
- CaDiCaL 3.0.1, built from source at commit
  `c60730422e758ef1cebe7aeddf2dda31c996bf04` (Apple clang 17.0.0, `-O3`).
- drat-trim, built from source at commit
  `2e3b2dc0ecf938addbd779d42877b6ed69d9a985`.
- Python 3.13.12 (project venv), OR-Tools 9.15.6755, python-sat 1.9.dev13.
- The historic session used OR-Tools CP-SAT on Python 3.12.3 and CaDiCaL 1.5.3
  (via pysat) plus a from-source CaDiCaL 2.x for the certified run†.

---

## 0. Pipeline validation (the part that earns the right to be believed)

Before any production run, the protocol requires the pipeline to reproduce
known theorems. All of these passed on the M4 on 11 Aug 2026:

- **Exact checkers** ([controls.py](../controls.py), log
  `results/logs/T1_controls.log`): the power set of a 4-element universe comes
  out closed, tight (margin exactly 0, maxfreq exactly $|F|/2$), and *not* a
  counterexample; a deliberately non-closed family is rejected; a
  low-frequency artificial input trips the detector but not the final verdict;
  checker 1 ([ucs_core.py](../ucs_core.py)) and checker 2
  ([checker2.py](../checker2.py)) agree on 50 random union-closures.
- **CP-SAT pipeline controls** (`results/logs/T1_cpsat_controls.log`):
  $\mathbb{Z}_7$ and $\mathbb{Z}_{11}$ INFEASIBLE — as they must be, since the
  conjecture is verified for all universes ≤ 12 points.
- **pysat pipeline controls** (`results/logs/T1_pysat_controls.log`): same
  instances, UNSAT.
- **Certification chain end-to-end** (`results/logs/T5_build.log`,
  `T5_validate.log`): `dump_dimacs.py` → CaDiCaL → drat-trim on
  $\mathbb{Z}_7$ (120 vars, 897 clauses) and $\mathbb{Z}_{11}$ (1,382 vars,
  123,568 clauses): `s UNSATISFIABLE` then **`s VERIFIED`** for both. These
  four files (CNF + DRAT for each) are small and **checked into the repo** at
  [results/dimacs/](../results/dimacs/), so you can replay a verification
  immediately.
- **Adder encoder self-validation**: [pb_adder.py](../pb_adder.py) was checked
  by brute force against explicit enumeration before first use
  (`results/logs/T1_pb_adder.log`).

Tripwires active in all runs: integer-only margin arithmetic, and abort if any
frequency ratio below 0.382 ever appears (it would contradict the proven
Alweiss–Huang–Sellke bound, hence flag an encoding bug). Neither ever fired.

---

## 1. $\mathbb{Z}_{13}$ — decided UNSAT, certified (historic session†, re-run on M4)

**Instance.** All 630 nontrivial orbits, *no size restriction*. CP-SAT closure
model: 1,863,311 clauses. DIMACS export: 4,752 variables (630 orbit + 4,122
adder auxiliaries), 1,884,943 clauses.

**Four concordant decisions, in increasing strength†:**
1. CP-SAT, native integer margin constraint: **INFEASIBLE**, 72 s† — re-run on
   the M4 on 11 Aug: **INFEASIBLE, 15.1 s** (`results/logs/T2_z13_decide.log`).
2. pysat/CaDiCaL 1.5.3, adder encoding: **UNSAT**, 325.6 s†.
3. CaDiCaL 2.x from source on the exported DIMACS: **`s UNSATISFIABLE`** with
   proof emission†.
4. **drat-trim on the 87 MB DRAT certificate: `s VERIFIED` in 266.75 s†** —
   481,643 lemmas in core, ≈ 39.8 million resolution steps.

**Quantitative margin result** (sizes ≥ 3, optimization mode): minimum margin
**M = 11**, scaled 143 = 13·11, status OPTIMAL; witness family = orbit of a
12-element set ∪ {∅, $\mathbb{Z}_{13}$}, $|F| = 15$, $f = 13$. Cross-checked by
independent enumeration ([cyclic_enum.py](../cyclic_enum.py)).

**Corollary** (Cauchy, [mathematics.md §6](mathematics.md#6-the-cauchy-corollary-why-13-is-special)):
the result covers families invariant under **any** transitive group on 13
points.

**Where recorded:** [RISULTATI.md](../RISULTATI.md) (Italian, primary record of
the historic session). The Z13 CNF/DRAT artifacts are regenerable
deterministically (`dump_dimacs.py 13 z13.cnf` → CaDiCaL → drat-trim).

## 2. $\mathbb{Z}_{14}$ — decided UNSAT, certified (M4, 11 Aug 2026)

**Instance.** 1,180 nontrivial orbits (periods 2 : 1 orbit, 7 : 18, 14 : 1,161);
sizes ≥ 3 forced out per reduction (R3). CP-SAT closure model: 7,320,454
clauses, model RSS 1.01 GB (probe: `results/logs/T3_probe_z14.log`).

**Method 1 — CP-SAT monolithic** (`results/logs/T4_z14_cpsat_min3.log`):
**`INFEASIBLE`** in about a minute (launched 15:35, log closed 15:36; cap was
1,150 s, never approached). Historical note: on the historic machine this same
monolithic model had OOM-killed at 3.94 GB†; on the M4 with a streaming build
it fit comfortably.

**Method 2 — CaDiCaL on independent CNF**
(`results/logs/T6_cadical_z14.log`): DIMACS `p cnf 5184 7342059` (117 MB,
non-binary proof mode), generated by `dump_dimacs.py 14 results/z14min3.cnf 3`
(`results/logs/T6_dump.log`). Result: **`s UNSATISFIABLE` (exit 20)** in
**2,240.10 s** process time (2,244.29 s wall), 8,155,223 conflicts, 16,085,260
decisions, 2,125,748,481 propagations, max RSS 2,518.05 MB.

An instructive detail from the solver trajectory: the "remaining variables"
column sat at 60–62% for the last twelve minutes and collapsed 62% → 50% →
verdict in the final 0.3 seconds. CDCL refutations end without warning — a fact
that matters when you try to forecast them (see
[open-problems.md](open-problems.md#the-feasibility-analysis)).

**Certificate** — `results/z14min3.drat`, 2,407,436,373 bytes (2.24 GB, text
DRAT). **drat-trim: `s VERIFIED`** (`results/logs/T6_drat_z14.log`) in
**1,736.034 s** verification time, RSS ≈ 1.55–1.70 GB throughout:
- 864,118 of 7,342,059 input clauses in core;
- **3,411,578 of 8,579,915 lemmas in core, using 315,224,851 resolution steps**;
- 0 RAT lemmas in core (the proof is pure RUP), 4,318,902 redundant literals;
- the parser's "duplicate literal" warnings are benign deduplications.

**Artifacts and integrity.** Recorded in [results/FOUND.md](../results/FOUND.md)
(Italian; includes a dated erratum correcting a transcribed clause count) and
hash-anchored in [results/FOUND.sha256](../results/FOUND.sha256):

```
f9283cb30b0b5dc78faa123d57774cf2589924b1066e0bb2f9d45732ca59bab4  results/z14min3.cnf
33494a39113e79d5cdd73a8960dbe639d55485805bdde385d6e0eb0c77738a87  results/z14min3.drat
```

Both hashes re-verified OK on 12 Aug 2026. The files themselves exceed GitHub
limits and are not in git; regeneration is deterministic for the CNF (same
generator code ⇒ same bytes) and the DRAT re-emitted by the same CaDiCaL commit
on the same CNF verifies identically even if not byte-identical.

## 3. $\mathbb{Z}_{15}$ — CP-SAT says infeasible; independent confirmation not completed

**Status: one exact method, no certificate — reported as unconfirmed.** The
complete factual record is [results/Z15-PARTIAL.md](../results/Z15-PARTIAL.md);
summary:

**Instance.** 2,190 nontrivial orbits (measured periods $\{3\!:\!2,\ 5\!:\!6,\
15\!:\!2182\}$, sanity-checked exactly), sizes ≥ 3. Closure clauses:
28,772,876; CP-SAT model RSS 2.41 GB (probe `results/logs/T9_probe_z15.log`).

**Method 1 — CP-SAT** (`results/logs/T9a_z15_cpsat_min3.log`):
**`INFEASIBLE`** in ~15 minutes (889 s), well under the 9 GB cap.

**Method 2 — CaDiCaL, stopped without verdict**
(`results/logs/T9b_cadical_z15.log`): DIMACS `p cnf 16856 28850111`
(515,753,359 bytes, sha256
`e6c732cf30bc619dd4c2706734bdcc2ed99255a422c52c4a8525563785115120`), binary
proof mode. Ran 21:02:56 (11 Aug) → 09:58:46 (12 Aug), when it was terminated
by owner decision after a feasibility analysis: **46,474.02 s** process time
(~12 h 56 m wall), 62,988,244 conflicts, 140,163,447 decisions,
33,683,721,828 propagations, 1,530,670 restarts, max RSS 5,454.59 MB. Solver
trajectory: remaining variables at 75% until hour 8, cascade to 51% by hour
9.4, then a plateau at 50% for the final ~3.6 hours. Partial DRAT trace:
12,747,632,134 bytes (11.87 GiB), preserved on disk, **not a certificate**.

**Why stopped.** Two findings of the (read-only) feasibility analysis, both
detailed in [open-problems.md](open-problems.md#the-feasibility-analysis):
survival modeling of the run gave only ~10–15% probability of a verdict within
the remaining budget; and — decisively — verifying the projected ~14 GiB
certificate with drat-trim was estimated at **11–18 GB of RAM** against 16 GB
physical. The bottleneck had become the *verifier's memory*, which no amount of
patience fixes. Note the format asymmetry: Z14's proof was text DRAT, Z15's is
binary (≈ 2–3× denser per lemma), so the two proof sizes are not directly
comparable in bytes; the RAM estimate is based on lemma counts, which are
format-independent.

**What would close Z15:** any one of — (a) a second independent solver
finishing (e.g. the sharded plan in open problem 1, sized for small machines);
(b) the monolithic CaDiCaL run plus drat-trim on a ≥ 32 GB machine; (c) a
verified checker run on a regenerated certificate. Until then, the honest
statement is: *CP-SAT, run once, found no rotation-invariant counterexample on
15 points.*

## 4. Negative and cautionary findings (kept because they cost real hours)

- **CEGAR (lazy closure) backfired.** Starting from the margin constraint alone
  and adding closure clauses only when violated is sound and was validated on
  $\mathbb{Z}_7/\mathbb{Z}_{11}$ — but on $\mathbb{Z}_{13}$ the relaxation was
  *harder* to refute than the full model (fewer constraints ⇒ weaker
  propagation ⇒ UNSAT proofs get longer). Lazy ≠ faster for refutation.
  ([cegar.py](../cegar.py), RISULTATI.md.)
- **The adder encoding propagates weakly** compared to CP-SAT's native linear
  constraint: on $\mathbb{Z}_{14}$† the pysat route timed out in-session where
  CP-SAT finished; the from-source CaDiCaL + certificate route is what made the
  CNF path viable. Encoding choice, not solver choice, was the lever.
- **Local search finds nothing** (and honestly cannot certify absence):
  [anneal.py](../anneal.py) converges to the power set from every start —
  consistent with a landscape whose every basin drains to margin ≥ 0.
- **Monolithic CP-SAT on Z14 OOM'd at 3.94 GB on the historic machine**† and
  was rescued by a streaming build + more RAM on the M4 — a reminder that
  memory ceilings, not time, kept deciding this project's fate.

## What you must trust

A candid audit of the trust chain, strongest link first:

1. **drat-trim** (≈ 3k lines of C, standard in SAT competitions since 2013)
   verified the Z13 and Z14 refutations end-to-end. You need not trust CaDiCaL.
2. **The formula generators** are the real residual trust surface: if
   `dump_dimacs.py`/`sat_cyclic.py` encoded the *wrong question*, a correct
   UNSAT proof of it would be worthless. Mitigations: two independently written
   encoders (different margin formalisms) agree on five universes; the control
   instances encode theorems with known answers; the orbit arithmetic is
   re-derived and re-checked in [mathematics.md](mathematics.md) §4–5.
3. **CP-SAT** has no certificate; it is one of the two independent methods, and
   on Z15 currently the only one — which is exactly why Z15 is labeled
   unconfirmed.
4. **Upgrade path for the skeptical**: re-verify the certificates with a
   *formally verified* checker (e.g. cake_lpr) — open problem 6. drat-trim
   itself is unverified C; running a verified checker would shrink the trusted
   base to the formula generator alone.

## Timeline (for the record)

| when (CEST) | what |
|---|---|
| 10 Aug 2026† | Z13 decided (4 methods) + margin minimum + DRAT certificate verified |
| 11 Aug, 13:31 | M4 bootstrap; controls pass; Z13 re-decided in 15.1 s |
| 11 Aug, 15:36 | Z14 CP-SAT: INFEASIBLE |
| 11 Aug, 16:18 | Z14 CaDiCaL: UNSAT (2,240 s), proof 2.24 GB |
| 11 Aug, 16:48 | **Z14 certificate VERIFIED (1,736 s) — Z14 closed** |
| 11 Aug, 20:57 | Z15 CP-SAT: INFEASIBLE (889 s) |
| 11 Aug, 21:03 | Z15 CaDiCaL launched |
| 12 Aug, 09:58 | Z15 CaDiCaL stopped without verdict after 12 h 56 m; project pivots to publication |
