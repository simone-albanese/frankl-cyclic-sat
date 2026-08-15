# FOUND — Valuable negative result on Z14 (criterion (b) of GOAL.md)

**Date:** 2026-08-11 16:48
**Outcome:** There exist no **Z14-invariant** union-closed families (generators
of size ≥ 3) with integer margin `2*maxfreq - |F| <= -1`. Frankl's conjecture
is confirmed on the entire Z14 class.

## Why criterion (b) is satisfied
GOAL.md requires: "UNSAT for Z14 (sizes ≥ 3) confirmed by two independent
solvers **or** with a DRAT certificate verified by drat-trim". Here **both**
conditions hold:

1. **CP-SAT (OR-Tools)** — T4: outcome `{"status": "INFEASIBLE", "m": 14}`.
   Log: `results/logs/T4_z14_cpsat_min3.log`.
2. **CaDiCaL** — T6: independent CNF encoding (`results/z14min3.cnf`,
   7,342,059 clauses), outcome `s UNSATISFIABLE` (exit 20).
   Log: `results/logs/T6_cadical_z14.log`.
3. **Verified DRAT certificate** — T6 closure: `drat-trim` on
   `results/z14min3.drat` (2.2 GB) answered **`s VERIFIED`**
   (backward checking, 1736.034 s; 3,411,578 lemmas in core,
   0 problematic RAT lemmas). Log: `results/logs/T6_drat_z14.log`.
   The "duplicate literal" warnings during parsing are benign (duplicate
   literals deduplicated, not errors).

## How to re-verify from scratch
```bash
# 1. Integrity of the artifacts (hashes in results/FOUND.sha256):
shasum -a 256 -c results/FOUND.sha256

# 2. Regenerate the CaDiCaL outcome + certificate (hours of computation):
tools/cadical/build/cadical results/z14min3.cnf results/z14min3.drat
#    expected: "s UNSATISFIABLE" (exit code 20)

# 3. Verify the certificate (~30 min, ~2 GB RAM):
tools/drat-trim/drat-trim results/z14min3.cnf results/z14min3.drat
#    expected: "s VERIFIED"

# 4. (Independent) sharded CP-SAT: T4 commands in the backlog,
#    .venv/bin/python3 — never bare python3.
```

## Artifacts (do NOT delete: they are the proof)
- `results/z14min3.cnf` — 117 MB — sha256 `f9283cb3…59bab4`
- `results/z14min3.drat` — 2.2 GB — sha256 `33494a39…738a87`
- `results/FOUND.sha256` — complete hashes
- Logs: `results/logs/T6_drat_z14.log`, `T6_cadical_z14.log`, `T4_z14_cpsat_min3.log`

## Context and follow-up
- Z13 was already decided (UNSAT + verified DRAT, see RISULTATI.md). This
  result extends the confirmation to Z14, the first open multi-orbit case.
- **Z15 is the natural follow-up** (backlog tasks T7+, already set up).
  GOAL.md declares SUCCESS with "any one" of the criteria, so the status
  is DONE: the decision whether to continue with Z15 rests with the human.

## Erratum (2026-08-12)
The clause count originally reported at point 2 (6,237,856) was a
transcription error: the correct value is **7,342,059**, as per the DIMACS
header (`p cnf 5184 7342059`), `results/logs/T6_dump.log`, and drat-trim's
parsing ("864118 of 7342059 clauses in core"). Corrected above; the hashes in
`results/FOUND.sha256` concern the `.cnf`/`.drat` files and remain unchanged
(re-verified OK on 2026-08-12).

*Originally written in Italian as the campaign's working record; translated to English on 15 Aug 2026 (the Italian original is preserved in git history).*
