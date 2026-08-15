# Research session: counterexamples to the union-closed (Frankl) conjecture

*("Risultati" = results; the filename is kept for link stability.)*

Date: 10 August 2026 · Environment: Python 3.12.3, OR-tools CP-SAT · Verdict arithmetic: integers only (counterexample condition: 2·maxfreq < |F|).

## 1. State of the art (Step 0, summary with sources in the chat)

The conjecture is open. Lower bounds on the maximum frequency: Gilmer 2022 (0.01·|F|), then (3−√5)/2 ≈ 0.38197 (Alweiss–Huang–Sellke; Chase–Lovett; Sawin; Pebody), refined to ≈ 0.38234 (Yu) and ≈ 0.3824–0.3827 (Liu, depending on the source). Chase–Lovett: (3−√5)/2 is optimal for the approximate version (a barrier for entropy methods). Exhaustive verifications: universes with ≤ 12 elements (Živković–Vučković 2017); families with ≤ 46 sets; if the minimal counterexample has m elements, every counterexample has ≥ 4m−1 sets (Lo Faro; Roberts–Simpson) → with m ≥ 13, |F| ≥ 51. A counterexample contains no sets of size 1 or 2 (Sarvate–Renaud). WLOG ∅ ∈ F (adding it preserves closure and lowers all relative frequencies). Transitive case: Aaronson–Ellis–Leader 2021 prove the conjecture for the family of ALL unions of the translates of ONE fixed set in an abelian group (the 1-seed case); the multi-orbit case does not appear to be covered.

## 2. Protocol checks (all passed)

- Negative control: P([4]) → |F|=16, maxf=8, margin 2·maxf−|F| = 0 exactly (tight, not a counterexample).
- Validator: {{0},{1}} rejected ({0,1} missing). This check uncovered a real control-flow bug in checker no. 1 (< 3 violations marked as "closed"), fixed before any run.
- Detector: six singletons → 2·maxf=2 < 6 detected; overall verdict correctly False (family not union-closed).
- Agreement between checker1 (bitmask) and checker2 (frozenset+Counter, independent implementation): 50/50 on random closures.

## 3. Main result (exact SAT, cyclic-invariant families)

Model: one Boolean variable for each of the 630 nontrivial cyclic orbits of Z₁₃ (∅ and Z₁₃ always included; their contributions to the margin cancel). Margin M = Σ (2s−13)x_O; closure: 1,863,311 clauses ¬x₁∨¬x₂∨x_target.

- Pipeline checks: Z₇ and Z₁₁ → INFEASIBLE (as the theory dictates: the conjecture is true for m ≤ 12). Encoding validated.
- **Z₁₃, constraint M ≤ −1: INFEASIBLE/UNSAT, now with a verified certificate.** Four concordant and progressively stronger confirmations: (1) CP-SAT, native linear constraint, 72 s; (2) pysat/CaDiCaL 1.5.3, binary-adder encoding validated by brute force, UNSAT in 325.6 s; (3) CaDiCaL 2.x compiled from source on the exported DIMACS (4752 variables, 1,884,943 clauses), s UNSATISFIABLE with proof emission; (4) **DRAT certificate (87 MB) verified by drat-trim: s VERIFIED in 266.75 s** (481,643 lemmas in the core, ~39.8 M resolution steps). The entire dump→solve→verify chain was first validated end-to-end on Z₇ and Z₁₁ (UNSAT + VERIFIED). Residual trust gap: only the correctness of the formula *generation*, mitigated by two independent, concordant encoders and by the checks. Since every transitive group on 13 points contains a 13-cycle (Cauchy), the result covers every family invariant under ANY transitive group on 13 points, and extends (experimentally) the 1-seed case of Aaronson–Ellis–Leader to the multi-seed case on Z₁₃.
- Optimization: min M = 0 (OPTIMAL), attained only by the power set (|F|=8192) — the trivial tight near-counterexample.
- Feasible region for a counterexample (sizes ≥ 3): min M = 11 (OPTIMAL), |F|=15 (the orbit of the 12-sets + Z₁₃ + ∅), f = 13, ratio 13/15 ≈ 0.867. Cross-check: the independent enumeration gives scaled margin 143 = 13·11 for the same family.

## 4. Complementary coverage

- Exhaustive 1-seed enumeration: Z₁₃ 630/630, Z₁₄ 1180/1180, Z₁₅ 666/666 (sizes ≤ 6 only, declared partial): zero candidates; tight only for the power set (possibly "blockwise"). Experimental confirmation of the AEL theorem.
- Sample of 800 seed pairs on Z₁₃: zero candidates; best margin M = 32 (|F|=54, ratio 43/54 ≈ 0.796).
- Annealing over the generators (m ≤ 16): free mode converges to the power set (margin 0 — successful calibration); mode with generators of size ≥ 3 (48 runs): best margin 2 (|F|=10, ratio 3/5 = 0.6). No negative margin.
- Structured constructions on 13 points (all with counts predicted by hand and verified): PG(2,3) → |F|=704, ratio 507/704 ≈ 0.720; cyclic STS(13) → |F|=4032, ratio 1205/2016 ≈ 0.598 (the best "structured" ratio); QR(13) → |F|=210, ratio 27/35 ≈ 0.771; intervals (runs ≥ 3) → |F|=522, ratio 37/58 ≈ 0.638. Up-sets excluded a priori (maxf ≥ |F|/2 by the injection S ↦ S∪{x}).

## 5. Second phase: attempts on Z₁₄/Z₁₅ and lessons

The monolithic CP-SAT model for Z₁₄ (7.32 M clauses) exceeds the available RAM (documented OOM-kill at 3.94 GB). Two routes explored: (a) CEGAR (lazy closure: start from the margin constraint alone and add clauses only when violated) — correct by construction and validated on Z₇/Z₁₁, but on Z₁₃ the relaxation turned out to be *harder* to refute than the full model (timeout: fewer constraints can make UNSAT harder); (b) a pysat/CaDiCaL pipeline with **streamed** clauses (C-side memory: Z₁₄ built in 13 s, ~930 MB steady) and margin via a binary-adder encoder. Route (b) produced the independent confirmation of Z₁₃; on Z₁₄ (restricted to sizes ≥ 3, a restriction valid for every counterexample, Sarvate–Renaud) the run remained without a verdict within the session budget: honest outcome UNKNOWN, with the bottleneck identified in the weak propagation of the pseudo-Boolean encoding compared to the native linear constraint.

## 6. Honest assessment

The certification step closes the first of the first phase's "next steps": the session theorem on Z₁₃ no longer depends on trusting a single solver. Multi-orbit Z₁₄ and Z₁₅ remain undecided (two CaDiCaL runs of 20+ minutes without a verdict; monolithic CP-SAT OOM at 3.94 GB): outcome declared UNKNOWN.

No candidates: every union-closed family examined has margin ≥ 0, and a ratio < 0.5 never appeared (consistent with the tripwire: never anything near 0.382). The session's nontrivial contribution is the exact decision of the general Z₁₃-invariant case (multi-orbit), which does not appear to be covered by the literature, together with the certified minimum margin M = 11 in the region without sizes 1–2. Limitations: multi-orbit Z₁₄ undecided (7.3 M clauses beyond the available memory), Z₁₅ SAT not attempted, heuristic annealing, CP-SAT without a verifiable certificate.

## 6. Next steps

(1) ~~DRAT certificate for Z₁₃~~ — done and verified in this session. (2) Multi-orbit Z₁₄/Z₁₅ with a compact encoding (pairwise auxiliary variables or a native PB solver). (3) Transitive groups on 14–16 points with no long cycles (where the Cauchy corollary does not apply). (4) Local search with surrogate objectives (mean size vs m/2) and moves on orbits rather than on generators.

## Files

`ucs_core.py` (bitmask, closure, checker no. 1) · `pb_adder.py` (self-validated PB encoder) · `sat2_cyclic.py` (pysat/CaDiCaL pipeline) · `cegar.py` (lazy refinement) · `dump_dimacs.py` (DIMACS export for the certification chain; z13.cnf and the 87 MB DRAT proof can be regenerated with dump_dimacs + CaDiCaL + drat-trim) · `checker2.py` (independent verifier) · `controls.py` (mandatory checks) · `cyclic_enum.py` (enumeration) · `sat_cyclic.py` (CP-SAT) · `anneal.py` (local search) · `structured.py` (constructions with manual asserts).

*Originally written in Italian as the campaign's working record; translated to English on 15 Aug 2026 (the Italian original is preserved in git history).*
