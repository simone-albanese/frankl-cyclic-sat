# Reproducing Everything

*Exact commands, expected costs, and the traps we already fell into so you
don't have to. Costs are measured on an Apple M4 with 16 GB RAM (macOS 15);
scale accordingly. If you only want to play, start with
[getting-started.md](getting-started.md) instead — this page is the full
production pipeline.*

---

## 1. Environment

```bash
python3 -m venv .venv
.venv/bin/python3 -m pip install -r requirements.txt   # ortools + python-sat
```

Tested with Python 3.13.12, OR-Tools 9.15.6755, python-sat 1.9.dev13. Always
invoke `.venv/bin/python3` explicitly: a bare `python3` may resolve to a system
interpreter without these packages (this exact trap cost the project an
iteration — see [STATE/lezioni.md](../STATE/lezioni.md)).

**Solver toolchain** (not vendored; build once, ~1 minute each):

```bash
mkdir -p tools && cd tools
git clone https://github.com/arminbiere/cadical && cd cadical
git checkout c60730422e758ef1cebe7aeddf2dda31c996bf04   # version used here (3.0.1)
./configure && make && cd ..
git clone https://github.com/marijnheule/drat-trim && cd drat-trim
git checkout 2e3b2dc0ecf938addbd779d42877b6ed69d9a985   # version used here
make && cd ../..
```

Binaries land at `tools/cadical/build/cadical` and `tools/drat-trim/drat-trim`.
Newer commits will almost certainly work; the pins reproduce the published runs.

## 2. The validation gauntlet (mandatory before believing anything)

The project rule: **a pipeline that has not reproduced known theorems has no
authority on unknown ones.** Run, in order:

```bash
# Exact checkers on known-answer instances (~1 s)
.venv/bin/python3 controls.py                # expect: TUTTI I CONTROLLI SUPERATI

# CP-SAT pipeline on Z7/Z11 (theorems: conjecture holds for ≤ 12 points) (~2 s)
.venv/bin/python3 sat_cyclic.py controls     # expect: INFEASIBLE, INFEASIBLE

# Certification chain end-to-end on Z7 and Z11 (~10 s)
.venv/bin/python3 dump_dimacs.py 7  /tmp/z7.cnf
tools/cadical/build/cadical --no-binary /tmp/z7.cnf /tmp/z7.drat ; echo "exit $?"   # expect exit 20 (UNSAT)
tools/drat-trim/drat-trim /tmp/z7.cnf /tmp/z7.drat                                  # expect: s VERIFIED
.venv/bin/python3 dump_dimacs.py 11 /tmp/z11.cnf
tools/cadical/build/cadical --no-binary /tmp/z11.cnf /tmp/z11.drat
tools/drat-trim/drat-trim /tmp/z11.cnf /tmp/z11.drat                                # expect: s VERIFIED
```

(Reference outputs of this gauntlet, as originally run, are in
`results/logs/T1_*.log` and `results/logs/T5_validate.log`; the Z7/Z11
CNF+DRAT artifacts are checked in under `results/dimacs/`.)

## 3. Reproducing $\mathbb{Z}_{13}$ (minutes)

```bash
# Method 1 — CP-SAT decision, all 630 orbits, no size restriction (~15 s on M4)
.venv/bin/python3 sat_cyclic.py decide13          # expect: INFEASIBLE

# Quantitative version — minimum margin over sizes ≥ 3 (~1–3 min)
.venv/bin/python3 sat_cyclic.py opt13min3         # expect: M = 11, |F| = 15

# Method 2 — certification chain (~10–30 min total on M4-class hardware)
.venv/bin/python3 dump_dimacs.py 13 results/z13.cnf        # 4752 vars, 1884943 clauses
tools/cadical/build/cadical --no-binary results/z13.cnf results/z13.drat   # expect exit 20
tools/drat-trim/drat-trim results/z13.cnf results/z13.drat                 # expect: s VERIFIED
```

Expected artifact sizes: CNF ≈ 30 MB, DRAT ≈ 87 MB, drat-trim RAM well under
1 GB. (Historic-machine reference: CaDiCaL emitted the proof and drat-trim
verified in 266.75 s at ≈ 4.8× slower speed.)

## 4. Reproducing $\mathbb{Z}_{14}$ (about an hour)

```bash
# Method 1 — CP-SAT, sizes ≥ 3 (~1 min, ~1 GB model RSS)
.venv/bin/python3 -c "import json,sat_cyclic; print(json.dumps(sat_cyclic.solve(14,'decide',time_cap=1150,min_set_size=3)))"
# expect: {"status": "INFEASIBLE", "m": 14}

# Method 2 — certification chain
.venv/bin/python3 dump_dimacs.py 14 results/z14min3.cnf 3   # p cnf 5184 7342059, 117 MB
tools/cadical/build/cadical --no-binary results/z14min3.cnf results/z14min3.drat
#   measured: s UNSATISFIABLE in 2240 s process time, max RSS 2.52 GB
tools/drat-trim/drat-trim results/z14min3.cnf results/z14min3.drat
#   measured: s VERIFIED in 1736 s, RSS ≈ 1.7 GB
#   (many "duplicate literal" parser warnings are benign)
```

Check your CNF against the published run:
`shasum -a 256 results/z14min3.cnf` →
`f9283cb30b0b5dc78faa123d57774cf2589924b1066e0bb2f9d45732ca59bab4`
(the generator is deterministic). Your DRAT may differ byte-for-byte from hash
`33494a39…738a87` if your CaDiCaL differs, and that is fine — *any* DRAT that
drat-trim verifies against this CNF is a valid certificate.

## 5. Attempting $\mathbb{Z}_{15}$ (here be dragons)

```bash
# Method 1 — CP-SAT (measured: INFEASIBLE in 889 s, model RSS 2.4 GB)
.venv/bin/python3 -c "import json,sat_cyclic; print(json.dumps(sat_cyclic.solve(15,'decide',time_cap=1100,min_set_size=3)))"

# Method 2 — the one that did NOT finish here (unbounded; read open-problems.md first)
.venv/bin/python3 dump_dimacs.py 15 results/z15min3.cnf 3   # p cnf 16856 28850111, 492 MB
# CNF sha256: e6c732cf30bc619dd4c2706734bdcc2ed99255a422c52c4a8525563785115120
tools/cadical/build/cadical results/z15min3.cnf results/z15min3.drat
```

Measured on the M4 before the run was stopped: 12 h 56 m without a verdict,
63.0 M conflicts, max RSS 5.45 GB, proof growing at ≈ 1.2 GiB/hour (binary
format), 11.87 GiB at stop. Budget accordingly:

| stage | time | RAM | disk | basis |
|---|---|---|---|---|
| dump CNF | minutes | ~2 GB | 0.5 GB | measured |
| CaDiCaL solve | **> 13 h, unbounded** | ~5.5 GB observed | ~1.2 GiB/h of proof | measured (no verdict) |
| drat-trim verify | 2.5–5 h *if RAM suffices* | **est. 11–18 GB** | — | extrapolated from Z14 (see [open-problems.md](open-problems.md#the-feasibility-analysis)) |

**On a 16 GB machine the verification step is expected to fail or swap-thrash.
A ≥ 32 GB machine is the honest minimum for the monolithic route.** The sharded
route (open problem 1) fits small machines instead.

## 6. Pitfalls (each one paid for in wall-clock)

- **drat-trim exits 0 on memory exhaustion.** Its `MEMOUT` paths print a
  message and `exit(0)` — *do not* trust the exit code; grep the log for the
  literal `s VERIFIED`.
- **Binary vs text DRAT.** `--no-binary` (used for Z7–Z14) produces larger but
  maximally compatible text proofs; the Z15 run used CaDiCaL's default binary
  format (~2–3× denser). drat-trim autodetects both. Proof *sizes* across
  formats are not comparable.
- **"Duplicate literal" warnings** from drat-trim on these proofs are benign
  (deduplicated literals), confirmed on the verified Z14 run.
- **Solver logs carry no verdict while running.** Liveness is checked with
  `ps`, never inferred from the log tail.
- **Never `cat` the big artifacts** (CNFs up to 0.5 GB, proofs up to 12 GB) —
  use `ls -l`, `head -c`, `tail`, `grep -c`.
- **CP-SAT is configured with `num_search_workers = 4`** in
  [sat_cyclic.py](../sat_cyclic.py) — on machines with fewer performance cores,
  pass a wrapper that lowers it rather than editing the source.
- **Long jobs**: run under `nice -n 10` and (macOS) `caffeinate -i`, guarded by
  [scripts/watchdog.sh](../scripts/watchdog.sh) —
  `watchdog.sh PID MAX_RSS_GB MAX_MINUTES LOGFILE` kills on RAM or time
  overrun, appending `KILL RAM`/`KILL TIMEOUT` to the log.
- **Interrupting CaDiCaL**: SIGTERM (not SIGKILL) makes it flush statistics and
  close the proof file cleanly.

## 7. Verifying published artifacts without recomputing

If someone hands you the original big artifacts (they are not in git — see
below), integrity-check them against
[results/FOUND.sha256](../results/FOUND.sha256) with
`shasum -a 256 -c results/FOUND.sha256`, then re-run only drat-trim: minutes
for Z13, ~29 min for Z14. That re-establishes the certified results from
scratch without re-running any solver.

**Where are the big files?** `results/*.cnf` and `results/*.drat` are excluded
from git (GitHub's 100 MB/file limit; the Z15 partial trace alone is 11.87
GiB). They currently live on the original machine. For permanent public
archival, a Zenodo deposit (free, DOI, 50 GB/dataset) of
`z14min3.cnf` + `z14min3.drat` (+ optionally the regenerated Z13 pair) is the
intended route; the DRAT text proofs compress well (`xz`, or drat-trim's
bundled `compress` tool) and would fit GitHub Releases (< 2 GiB/asset) after
compression. Until such a deposit exists, regeneration per §3–4 *is* the
distribution mechanism, and the hashes above are the ground truth for the CNFs.
