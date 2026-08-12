# Frankl's Union-Closed Sets Conjecture Under Rotational Symmetry

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21900943.svg)](https://doi.org/10.5281/zenodo.21900943)

**A computer-assisted case study: no rotation-symmetric counterexample exists on 13
or 14 points — with machine-checkable certificates — and a precisely documented
attempt at 15 points that ran into the memory wall of a 16 GB laptop.**

This repository contains everything: the mathematics, the code, the solver logs,
the proof-certificate hashes, the resource measurements, the open problems, and
the complete working diary of the autonomous AI agent that carried out the search.
Nothing here assumes you already know what a SAT solver is, and nothing important
is hidden in a paper you cannot access. If you have a laptop and some curiosity,
you can re-run the small cases yourself in under a minute and verify a real proof
certificate in seconds ([docs/getting-started.md](docs/getting-started.md)).

---

## The conjecture, in plain words

Take any finite collection of finite sets, with one rule: whenever two sets are
in the collection, their union must also be in it. Such a collection is called
**union-closed**. For example:

```
{a}   {a,b}   {c}   {a,c}   {b,c}   {a,b,c}
```

Check it: the union of any two of these sets is again one of these sets (for
instance {a} ∪ {c} = {a,c} ✓, {a,b} ∪ {c} = {a,b,c} ✓).

In 1979 Péter Frankl conjectured something that sounds almost too modest to be
hard:

> **In every union-closed family (containing at least one nonempty set), some
> element belongs to at least half of the sets.**

In the example above there are 6 sets, and the element *c* appears in 4 of them
— more than half, as the conjecture predicts. Try to build a union-closed family
where *every* element appears in fewer than half of the sets and you will feel
the difficulty immediately: unions keep creating big sets, big sets contain many
elements, and the frequencies get pushed up. Yet nobody has been able to prove
that this must always happen. The problem has been open for over forty-five
years and is considered one of the most embarrassing gaps in combinatorics —
easy to state to a child, unsolved by everyone.

What *is* known, briefly. In 2022 Justin Gilmer stunned the field by proving
that some element always appears in at least a 0.01 fraction of the sets — the
first constant bound ever. Within weeks, several groups (Alweiss–Huang–Sellke,
Chase–Lovett, Sawin, Pebody) pushed the constant to $(3-\sqrt5)/2 \approx
0.38197$, later refined slightly (≈ 0.3823–0.3827 by Yu and Liu). The full
conjecture asks for 0.5, and Chase and Lovett showed that ≈ 0.38197 is a real
barrier for the current proof technique. On the exhaustive side, the conjecture
has been verified for every family whose ground set has at most 12 elements
(Živković–Vučković 2017) and for every family with at most 46 sets. It is also
known that a minimal counterexample on an $m$-element universe must contain at
least $4m-1$ sets, and that it cannot contain any set of size 1 or 2.

So the first genuinely unknown universe size is **13** — and on 13 points, a
counterexample would need at least 51 sets chosen among the 8,192 subsets. The
number of union-closed families living there is beyond astronomical. Brute force
is dead on arrival. You need an idea.

## The idea: look where symmetry lives

Here is the observation that makes this project possible, and it fits in three
sentences.

Arrange the 13 points on a clock face and consider only families that look the
same after rotating the clock by one position — **rotation-invariant** families.
In such a family every element automatically has the *same* frequency $f$ (the
rotation carries element 0 to element 1 to element 2…, so no element can be
special). The conjecture for these families becomes a single clean inequality:
counting incidences two ways gives $f \cdot m = \sum_{S \in F} |S|$, so

$$\text{some element in at least half the sets} \iff 2f \ge |F| \iff \sum_{S\in F}\bigl(2|S| - m\bigr) \ge 0 .$$

In words: **a rotation-invariant family satisfies Frankl's conjecture exactly
when its members' "size excesses" over $m/2$ sum to a nonnegative number.** A
counterexample would be a union-closed family dominated by small sets — while
union-closure keeps manufacturing large sets out of small ones. The entire
computation below is the war between those two forces, fought exactly.

Why is this the natural place to hunt? A counterexample needs *every* element to
be rare. In an arbitrary family you must arrange that for all 13 elements
separately; symmetry gives it to you wholesale — if one element is rare, all
are. Rotation-invariant families are simultaneously the most promising hunting
ground for counterexamples and a small enough world to search completely: a
rotation-invariant family is a union of **orbits** (a set together with all its
rotations), and on 13 points there are only **630** nontrivial orbits. Choosing
a family means choosing a subset of 630 orbits — $2^{630}$ possibilities, still
huge, but now shaped exactly like a problem that modern SAT solvers eat for
breakfast: 630 Boolean variables, one clause per union-closure condition, one
arithmetic constraint for the margin.

There is a bonus. By a classical theorem of Cauchy, every transitive permutation
group on 13 points (13 being prime) contains a 13-cycle. Consequence: settling
the rotation-invariant case on 13 points automatically settles the case of
families invariant under *any* transitive symmetry group on 13 points. Symmetry
was not a restriction of convenience — on 13 points it was the whole transitive
story.

## What was established

Three results, in decreasing order of certainty. Precise statements, models and
proofs of the supporting lemmas are in [docs/mathematics.md](docs/mathematics.md);
every number below is anchored to a log file in this repository and discussed in
[docs/results.md](docs/results.md).

**Result 1 (13 points — decided and certified).**
*No union-closed family of subsets of $\mathbb{Z}_{13}$ that is invariant under
rotation violates Frankl's conjecture.* By Cauchy's theorem this extends to
invariance under any transitive group on 13 points. The search space (all 630
orbits, no size restriction) was decided infeasible by two independent exact
methods — Google's CP-SAT with a native integer constraint, and the CaDiCaL SAT
solver on an independently generated CNF encoding — and the SAT refutation
carries a **DRAT proof certificate (87 MB) verified by the independent checker
drat-trim** (481,643 core lemmas, ≈ 39.8 million resolution steps). There is
also a quantitative version: among such families with member sets of size ≥ 3,
the margin $2f - |F|$ never goes below **+11**, and the minimum is attained by
an explicitly known 15-set family. Even the *worst* symmetric family clears the
conjecture's bar with room to spare.

**Result 2 (14 points — decided and certified).**
*No union-closed family of subsets of $\mathbb{Z}_{14}$ invariant under rotation
violates the conjecture.* Since a counterexample may not contain sets of size 1
or 2 (classical), the search ran over the 1,180 nontrivial orbits with sizes ≥ 3
forced out. Again two independent methods agree: CP-SAT (infeasible, about a
minute) and CaDiCaL on a 7,342,059-clause CNF (unsatisfiable in 2,240 s), with
a **2.24 GB DRAT certificate verified by drat-trim in 1,736 s** — 3,411,578
lemmas in core, 315,224,851 resolution steps, zero problematic RAT lemmas. The
14-point case is genuinely richer than 13: since 14 is not prime, orbits come in
three different periods (2, 7, 14), and — unlike on 13 points — the transitive
story is *not* automatically covered (see open problem 4).

**Result 3 (15 points — decided by one method, honestly unconfirmed).**
CP-SAT declares the 15-point instance (2,190 orbits, 28.8 million closure
clauses, sizes ≥ 3) **infeasible in ~15 minutes**. Taken at face value: no
rotation-invariant counterexample exists on 15 points either. But this project's
own standard demands two independent methods or a verified certificate, and the
independent confirmation did not finish: CaDiCaL ran for **12 h 56 m** (63.0
million conflicts, 33.7 billion propagations) without a verdict and was stopped,
leaving an 11.87 GiB partial proof trace that certifies nothing. A feasibility
analysis (in [docs/open-problems.md](docs/open-problems.md)) showed that even on
success, verifying the projected ~14 GiB certificate would need an estimated
11–18 GB of RAM — more than this machine has. **We therefore report Z15 as
unconfirmed**, with the exact input formula, its SHA-256 hash, the full solver
statistics, and a concrete completion plan for anyone with a bigger machine.
This is a deliberate act of intellectual honesty: one solver's word, however
plausible, is not the standard this repository sells.

To the best of our knowledge, the certified multi-orbit results on 13 and 14
points do not appear in the literature (the closest published result,
Aaronson–Ellis–Leader 2021, covers families generated by the translates of a
*single* set in an abelian group; the families here may mix arbitrarily many
orbits). We would be glad to be corrected — if you know a reference, please open
an issue.

## How the results are protected against error

A computation that claims to settle 2^630 cases deserves paranoia. The project's
protocol, inherited from the certified-SAT tradition:

1. **Two independent encodings, two independent solvers.** The CP-SAT model
   states the margin as a native integer linear constraint; the CNF pipeline
   re-encodes it through a self-validated binary-adder circuit
   ([pb_adder.py](pb_adder.py)) and is generated by different code. A bug would
   have to occur twice, in different formalisms, with identical effect.
2. **Proof certificates.** For the SAT route the solver emits a DRAT trace — a
   complete, replayable derivation of the contradiction — which the independent
   checker [drat-trim](https://github.com/marijnheule/drat-trim) verifies. You
   do not have to trust CaDiCaL (≈ 100k lines of optimized C++); you only have
   to trust the checker and the 60-line formula generator.
3. **Control instances before every production run.** The same pipeline must
   first reproduce known theorems: unsatisfiability on $\mathbb{Z}_7$ and
   $\mathbb{Z}_{11}$ (covered by the ≤ 12-point verification) and exact behavior
   on the power set of a 4-element set, where the answer is known to be tight.
   A pipeline that has not passed the controls is not believed
   ([controls.py](controls.py)).
4. **Integer-only verdicts.** The counterexample condition is evaluated as
   $2 \cdot \text{maxfreq} < |F|$ over integers, never as floating-point ratio
   comparison. A tripwire aborts everything if any frequency ratio ever drops
   below 0.382 — the proven lower bound — since that can only mean an encoding
   bug.
5. **Two independent family checkers.** Any candidate counterexample would have
   to pass [ucs_core.check_family](ucs_core.py) *and* the separately written
   [checker2.verify](checker2.py) before being announced. (None ever appeared.)

What residual trust remains? Chiefly the correctness of the orbit/closure
*formula generator* — mitigated by the two independent encoders agreeing on
three different universes, and by the control instances. The full trust audit,
including what a verified checker (cake_lpr) would add, is in
[docs/results.md](docs/results.md#what-you-must-trust).

## The numbers

Everything measured, nothing rounded for effect. "Historic machine" is the
~4.8× slower machine of the first session (10 Aug 2026, times marked †);
everything else ran on a MacBook with Apple M4, 16 GB RAM, macOS 15.6.1.
Full provenance (solver commits, exact commands, log paths):
[docs/results.md](docs/results.md).

| | $\mathbb{Z}_7$ | $\mathbb{Z}_{11}$ | $\mathbb{Z}_{13}$ | $\mathbb{Z}_{14}$ | $\mathbb{Z}_{15}$ |
|---|---|---|---|---|---|
| nontrivial orbits | 18 | 186 | 630 | 1,180 | 2,190 |
| role | control | control | result | result | attempt |
| size restriction | none | none | none | ≥ 3 | ≥ 3 |
| CNF variables | 120 | 1,382 | 4,752 | 5,184 | 16,856 |
| CNF clauses | 897 | 123,568 | 1,884,943 | 7,342,059 | 28,850,111 |
| CP-SAT verdict | INFEASIBLE, <1 s | INFEASIBLE, ~1 s | INFEASIBLE, 15.1 s (72 s†) | INFEASIBLE, ~1 min | INFEASIBLE, 889 s |
| CaDiCaL verdict | UNSAT | UNSAT | UNSAT† | UNSAT, 2,240 s | **none** (stopped at 46,474 s) |
| DRAT certificate | 2 KB | 3.6 MB | 87 MB† | 2.24 GB | 11.87 GiB partial — *not a certificate* |
| drat-trim | VERIFIED | VERIFIED | VERIFIED, 267 s† | VERIFIED, 1,736 s | not run (est. 11–18 GB RAM) |

The tiny $\mathbb{Z}_7$ and $\mathbb{Z}_{11}$ certificates are checked into the
repository (`results/dimacs/`), so you can run drat-trim on a real certificate
seconds after cloning. The large CNF/DRAT files exceed GitHub's limits and are
excluded from git; they are deterministic outputs of the pipeline, their
SHA-256 hashes are recorded in [results/FOUND.sha256](results/FOUND.sha256) and
[results/Z15-PARTIAL.md](results/Z15-PARTIAL.md), and the three with evidential
value (the Z14 CNF + verified certificate, and the Z15 CNF) are downloadable
xz-compressed from
[release v1.0.0](https://github.com/simone-albanese/frankl-cyclic-sat/releases/tag/v1.0.0)
and permanently archived at Zenodo:
[doi:10.5281/zenodo.21900943](https://doi.org/10.5281/zenodo.21900943).

## Where it stopped: the 16 GB wall

The honest climax of this project is not a theorem but a resource analysis.
Between 13 and 15 points, every cost multiplied by roughly 4× per step — except
solver time, which is not a smooth function of size at all: Z14 fell in 37
minutes; Z15, four times larger, consumed 13 hours without falling. Worse, the
bottleneck silently changed identity. It was never really about solver time:
the DRAT trace grows at ~1.2 GiB/hour, and the *verifier* (drat-trim) holds the
whole proof in RAM. On the measured Z14 baseline, verifying the projected Z15
certificate extrapolates to 11–18 GB of resident memory. The machine has 16.

So the frontier of this project is not "we ran out of cleverness" but "we ran
out of RAM in the checker, and we can tell you exactly how much you would
need." The full analysis — measured versus extrapolated, clearly separated —
plus three concrete continuation routes (a 2^k sharding plan that fits small
machines, a bigger-RAM monolithic route, and encoding improvements) is in
[docs/open-problems.md](docs/open-problems.md). $\mathbb{Z}_{16}$ (4,114 orbits)
and $\mathbb{Z}_{17}$ (7,710 orbits) are also costed there: 16 breaks first on
time and then on disk, 17 breaks immediately on RAM.

## Try it in five minutes

```bash
git clone <this-repository> && cd <this-repository>
python3 -m venv .venv && .venv/bin/python3 -m pip install -r requirements.txt

# 1. The control gauntlet: exact checkers agree on everything known (~1 s)
.venv/bin/python3 controls.py

# 2. Re-prove: no rotation-symmetric counterexample on 7 or 11 points (~2 s)
.venv/bin/python3 sat_cyclic.py controls

# 3. Decide the first open universe size yourself (~15 s on an M4)
.venv/bin/python3 sat_cyclic.py decide13
```

That third command settles the rotation-invariant case of the first genuinely
open universe size of Frankl's conjecture, on your laptop, before your coffee
cools. The guided tour — including verifying a real DRAT certificate and
finding the *tightest* symmetric families — is in
[docs/getting-started.md](docs/getting-started.md).

## The repository, mapped

| path | what it is |
|---|---|
| [docs/mathematics.md](docs/mathematics.md) | definitions, the margin identity, reductions, orbit counts, Cauchy corollary — with proofs |
| [docs/results.md](docs/results.md) | every result with full measurement, provenance and trust audit |
| [docs/reproducing.md](docs/reproducing.md) | exact commands, expected costs (time/RAM/disk), pitfalls |
| [docs/getting-started.md](docs/getting-started.md) | the amateur's on-ramp, no prerequisites |
| [docs/open-problems.md](docs/open-problems.md) | what remains, what it costs, where to start |
| [docs/ai-workflow.md](docs/ai-workflow.md) | how an AI agent loop ran this project autonomously |
| [docs/playbook.md](docs/playbook.md) | the reusable field guide: what breaks (and what to copy) when attacking other open problems with this agent + hardware configuration |
| [ucs_core.py](ucs_core.py) | bitmask families, closure, exact checker no. 1 |
| [checker2.py](checker2.py) | independent checker no. 2 |
| [controls.py](controls.py) | the mandatory control gauntlet |
| [cyclic_enum.py](cyclic_enum.py) | orbit ("necklace") enumeration and margin landscape |
| [sat_cyclic.py](sat_cyclic.py) | CP-SAT exact decision (method no. 1) |
| [pb_adder.py](pb_adder.py) | self-validated pseudo-Boolean adder encoder |
| [sat2_cyclic.py](sat2_cyclic.py) | pysat/CaDiCaL pipeline (method no. 2) |
| [dump_dimacs.py](dump_dimacs.py) | DIMACS export for the certification chain |
| [cegar.py](cegar.py), [anneal.py](anneal.py), [structured.py](structured.py) | explored side roads (lazy closure, local search, constructions) |
| [results/](results/) | verdict records, certificate hashes, solver logs |
| [setup_frankl.sh](setup_frankl.sh) | the genesis artifact: a self-extracting script that recreates the project's seed files (verified byte-identical to the tracked copies) |
| [RISULTATI.md](RISULTATI.md), [STATE/](STATE/), [CLAUDE.md](CLAUDE.md) | the original working notes and diary (Italian) — primary sources |

## How this was made

Every computation in this repository was planned, launched, monitored and
recorded by an AI agent running in an autonomous loop built on
**[Claude Code](https://claude.com/claude-code)**, Anthropic's terminal agent
(model pinned to Claude Fable 5, no fallback): ~160 short fresh-context
headless sessions over two days, each spawned by a 100-line bash driver
([scripts/loop.sh](scripts/loop.sh)) with one instruction — read the
constitution and the handoff file, execute one atomic task, terminate — under
hard resource budgets, OS-level watchdogs, and a protocol that forbids
declaring success without independent verification. The human owner set the
goals, granted (and three times extended) time budgets, and made the final
call — in an interactive session — to stop Z15 and publish. The full setup
(exact CLI invocation, permission model, per-task effort dial), including what
failed and the operational lessons learned, is documented in
[docs/ai-workflow.md](docs/ai-workflow.md); the raw diary (1,297 lines,
Italian) is preserved verbatim in [STATE/journal.md](STATE/journal.md).

## Contributing

The most valuable contribution right now is **independent confirmation of
Z15** — see [docs/open-problems.md](docs/open-problems.md), problem 1, which
includes a sharding plan sized for ordinary machines. Literature pointers
(especially any prior work on the multi-orbit cyclic case), bug reports in the
encodings, and verified-checker runs of the certificates are all welcome. Open
an issue; measured numbers beat opinions.

## License and citation

MIT for everything (code, encodings, documentation). If you build on this,
cite via [CITATION.cff](CITATION.cff).

## References

- P. Frankl, circa 1979 — the conjecture (see the surveys below for its history).
- H. Bruhn, O. Schaudt, *The journey of the union-closed sets conjecture*,
  Graphs and Combinatorics 31 (2015) — the standard survey.
- J. Gilmer, *A constant lower bound for the union-closed sets conjecture*,
  arXiv:2211.09055 (2022).
- R. Alweiss, B. Huang, M. Sellke, arXiv:2211.11731; Z. Chase, S. Lovett,
  arXiv:2211.11689; W. Sawin, arXiv:2211.11504; L. Pebody, arXiv:2211.12401
  (2022) — the $(3-\sqrt5)/2$ bound; refinements by Yu and by Liu (2023).
- I. Živković, B. Vučković, verification for universes with ≤ 12 elements (2017).
- D. G. Sarvate, J.-C. Renaud — no sets of size 1 or 2 in a counterexample;
  G. Lo Faro; I. Roberts, J. Simpson — a minimal counterexample on $m$ elements
  has at least $4m-1$ sets.
- J. Aaronson, D. Ellis, I. Leader, *Union-closed families generated by the
  translates of a fixed set in an abelian group* (2021) — the 1-orbit transitive
  case.
- A. Biere et al., *CaDiCaL* SAT solver; M. Heule, *drat-trim* proof checker.
