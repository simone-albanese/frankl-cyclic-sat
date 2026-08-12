# Getting Started (No Prerequisites)

*This page assumes nothing: not SAT solvers, not group theory, not even that
you have read the rest of the repository. It is written for the curious
amateur — the person the union-closed conjecture was practically made for,
since it can be explained in one minute and attacked with a laptop. Every
output shown below is the real output of the command above it.*

---

## 0. The one-minute version of the problem

Collect some finite sets, with one house rule: **the union of any two sets in
your collection must also be in the collection.** Frankl's conjecture says that
no matter how cleverly you build such a collection, some element ends up in at
least half of your sets. Nobody has proved it. Nobody has found a counterexample.
This repository closes off one natural hiding place — collections symmetric
under rotation, on 13, 14 (and, pending confirmation, 15) points — and hands
you the tools to push further.

## 1. Setup (2 minutes)

You need Python 3.10+ and, later, a C compiler. From the repository root:

```bash
python3 -m venv .venv
.venv/bin/python3 -m pip install -r requirements.txt
```

From now on always use `.venv/bin/python3` (a bare `python3` may lack the
installed packages).

## 2. First contact: watch the checkers pass a known exam

```bash
.venv/bin/python3 controls.py
```

This runs the project's control gauntlet: families with *known* answers must
come out exactly right, two independently written checkers must agree on random
instances, and deliberately broken inputs must be rejected. It ends with
`TUTTI I CONTROLLI SUPERATI` ("all controls passed"). The project's cardinal
rule: **no tool is believed until it has passed an exam it cannot fake.**

## 3. Play with families by hand

Open a REPL (`.venv/bin/python3`) and build the smallest interesting example.
Sets are represented as bitmasks — the integer `0b0111` is the set {0, 1, 2}:

```python
>>> from ucs_core import closure, check_family, family_to_sets
>>> fam = set(closure([0b0111, 0b1100])) | {0}     # union-close two sets, add ∅
>>> family_to_sets(fam, 4)
[(), (0, 1, 2), (2, 3), (0, 1, 2, 3)]
>>> r = check_family(fam, 4)
>>> r["F"], r["maxf"], r["margin"], r["is_counterexample"]
(4, 3, 2, False)
```

Four sets; element 2 appears in three of them; margin
$2\cdot\mathrm{maxf} - |F| = 2 \ge 0$ — the conjecture holds here, with room to
spare. Try to make `margin` negative. You will find that unions keep betraying
you: every union you are forced to add is a *big* set, and big sets push
frequencies up. That frustration you feel is the conjecture.

Now the symmetric world. Take the "necklace" {0,1} on a 5-point circle and
close its rotations under union:

```python
>>> from cyclic_enum import cyclic_closure_from_seeds, analyze
>>> fam5 = cyclic_closure_from_seeds((0b00011,), 5)
>>> analyze(fam5, 5)          # (|F|, sum of sizes, scaled margin 2Σ|S| − m|F|)
(17, 50, 15)
>>> check_family(set(fam5) | {0}, 5)["freq"]
[10, 10, 10, 10, 10]
```

Look at that frequency list: **all five elements appear in exactly 10 of the 17
sets.** That is the symmetry lemma made flesh — in a rotation-invariant family
no element can be special — and it is why symmetric families are *the* natural
place to hunt counterexamples: you need every element to be rare, and symmetry
makes all of them rare (or abundant) together. Here $2\cdot 10 - 17 = 3 > 0$,
so this family, too, obeys Frankl.

How big is the symmetric world? Count the building blocks (orbits/necklaces):

```python
>>> from cyclic_enum import necklaces
>>> len(necklaces(13, 1, 12))
630
```

630 orbits on 13 points; a symmetric family is any union-closed choice among
them — $2^{630}$ candidates, which is why the next step hands the work to a
solver.

## 4. Prove a theorem on your laptop

```bash
.venv/bin/python3 sat_cyclic.py controls    # Z7, Z11: INFEASIBLE (sanity, ~2 s)
.venv/bin/python3 sat_cyclic.py decide13    # ~15 s on an M4
```

The second command prints `DECISIONE Z_13, vincolo M<=-1: INFEASIBLE`
("decision for Z13, constraint M ≤ −1: infeasible"). Read it slowly: the
solver just checked, exhaustively and exactly, that **none of the $2^{630}$
rotation-symmetric families on 13 points violates Frankl's conjecture** — the
first universe size not already covered by the literature. On your machine, in
the time of a sneeze (a 15-second sneeze).

Then ask the sharper question — how *close* does the symmetric world get to a
counterexample?

```bash
.venv/bin/python3 sat_cyclic.py opt13min3   # a few minutes
```

Answer: the margin never drops below **+11**, and the extremal family is
beautiful — the thirteen 12-element sets plus ∅ and the full set.

## 5. Touch a real proof certificate

"The solver said so" is not the trust model here. For the flagship results the
SAT solver wrote down a complete, replayable refutation (a DRAT file), and an
independent 3,000-line checker replayed it. The small certified instances are
in the repo; build the checker and replay one right now:

```bash
mkdir -p tools && cd tools && git clone https://github.com/marijnheule/drat-trim
cd drat-trim && make && cd ../..
tools/drat-trim/drat-trim results/dimacs/z11.cnf results/dimacs/z11.drat
```

Last line: **`s VERIFIED`**. You have just independently verified a computer
proof that no rotation-symmetric family on 11 points beats the conjecture. The
13- and 14-point certificates are the same thing scaled up (87 MB and 2.24 GB;
regeneration recipes in [reproducing.md](reproducing.md)).

## 6. What finding something would look like

If you experiment with encodings and a solve ever returns `FEASIBLE`/`SAT`,
**do not celebrate — verify.** The project discipline, in order:

1. Rebuild the explicit family from the model (`chosen_reps` in the output).
2. Run it through **both** independent checkers: `ucs_core.check_family` *and*
   `checker2.verify`. Both must say: closed ✓, and $2\cdot\mathrm{maxf} < |F|$
   on integers.
3. Distrust ratios below 0.382: the theorem of Alweiss–Huang–Sellke proves the
   true maximum frequency ratio is always above $(3-\sqrt5)/2 \approx 0.38197$,
   so anything below it is an encoding bug, full stop.
4. If it survives all that, you have a candidate refutation of a 45-year-old
   conjecture. (More likely: a fascinating bug. The project found several of
   the latter and none of the former.)

## 7. Rules of the road for your own experiments

- **Know your budget.** Z13 costs seconds, Z14 an hour, Z15 ate 13 hours and
  did not finish, and verifying Z15's certificate is estimated to need more
  RAM than a 16 GB laptop has. Read
  [open-problems.md](open-problems.md#the-feasibility-analysis) before
  launching anything with $m \ge 15$.
- **Guard long runs.** `scripts/watchdog.sh PID MAX_GB MAX_MIN LOGFILE` kills a
  runaway job on RAM or time; `nice -n 10` keeps your machine usable;
  `caffeinate -i` (macOS) keeps it awake.
- **Validate before trusting.** Any modified encoding must re-pass §2 and the
  Z7/Z11 solves before its verdicts on open cases mean anything.
- **Integers only.** Margins are compared as integers, never as floats.

## 8. Where to go next

- The mathematics behind everything you just ran, with proofs:
  [mathematics.md](mathematics.md)
- What exactly is established, with every measurement:
  [results.md](results.md)
- **The frontier, ranked by feasibility — including one problem sized exactly
  for a patient amateur with an ordinary laptop:**
  [open-problems.md](open-problems.md)
