"""sat2_cyclic.py — Seconda pipeline, solver indipendente (pysat/CaDiCaL).

Stessa domanda di sat_cyclic (esiste un controesempio Z_m-invariante?) con
stack completamente diverso: clausole di chiusura aggiunte in STREAMING al
solver C (memoria Python trascurabile: risolve l'OOM di Z_14) e vincolo di
margine  Σ d_O x_O ≤ -1  con d_O = r_O(2 s_O - m)/m  (sempre intero perché
m | r_O·s_O) codificato dall'encoder ad addizionatori binari di pb_adder
(validato per forza bruta).

Ruolo doppio: (1) su Z_13 fornisce la conferma con SECONDO SOLVER
indipendente del risultato CP-SAT; (2) su Z_14 e Z_15 produce decisioni
nuove, fuori portata per l'encoding monolitico.

CONTROLLI: Z_7 e Z_11 devono dare UNSAT prima di credere a qualunque
altro esito. Timeout in-process via Timer+interrupt (esito onesto
"UNKNOWN" se scade).
"""
import sys, time, threading
from pysat.solvers import Cadical153
from ucs_core import rot
from sat_cyclic import canon_table, build_orbits
from pb_adder import Pool, encode_signed_leq


def decide(m, wall_cap=240, verbose=True, pair_filter="all", min_size=1):
    t0 = time.time()
    tab = canon_table(m)
    reps, info, idx = build_orbits(m, tab)
    n = len(reps)
    full = (1 << m) - 1
    orbit_sets = [sorted({rot(c, k, m) for k in range(m)}) for c, _, _ in info]
    d = []
    for (_, r, s) in info:
        assert (2 * r * s) % m == 0, "coefficiente non intero: bug"
        d.append((2 * r * s) // m - r)

    solver = Cadical153()
    if min_size > 1:  # valido per controesempi: nessun insieme di taglia 1-2
        for i in range(n):
            if info[i][2] < min_size:
                solver.add_clause([-(i + 1)])
    # ---- margine: Σ d_i x_i ≤ -1 (variabili 1..n) ----
    pool = Pool(n + 1)
    pb = encode_signed_leq({i + 1: d[i] for i in range(n) if d[i] != 0}, -1, pool)
    for c in pb:
        solver.add_clause(c)
    solver.add_clause(list(range(1, n + 1)))  # almeno un'orbita
    # ---- chiusura in streaming ----
    n_cl = 0
    pairs = 0
    neg_idx = {i for i in range(n) if d[i] < 0}
    for i in range(n):
        Ai = reps[i]
        for j in range(i, n):
            if pair_filter == "neg" and i not in neg_idx and j not in neg_idx:
                continue  # rilassamento sano: UNSAT resta valido
            pairs += 1
            seen = set()
            for B in orbit_sets[j]:
                u = Ai | B
                if u == full:
                    continue
                t = idx[tab[u]]
                if t == i or t == j or t in seen:
                    continue
                seen.add(t)
                solver.add_clause([-(i + 1), -(j + 1), t + 1])
                n_cl += 1
        if time.time() - t0 > wall_cap:
            return {"status": "UNKNOWN(build-cap)", "m": m, "clauses": n_cl}
    tb = time.time() - t0
    if verbose:
        print(f"  Z_{m}: {n} orbite, PB {len(pb)} cls (aux fino a v{pool.next-1}), "
              f"chiusura {n_cl} cls su {pairs} coppie [{pair_filter}] (build {tb:.0f}s)")
    # ---- solve con interrupt ----
    budget = max(5.0, wall_cap - (time.time() - t0))
    timer = threading.Timer(budget, solver.interrupt)
    timer.start()
    res = solver.solve_limited(expect_interrupt=True)
    timer.cancel()
    dt = time.time() - t0
    if res is None:
        return {"status": "UNKNOWN(solve-cap)", "m": m, "secs": round(dt, 1),
                "clauses": n_cl}
    if res is False:
        note = "" if pair_filter == "all" else " (rilassamento neg-pairs: esito comunque valido)"
        return {"status": "UNSAT" + note, "m": m, "secs": round(dt, 1),
                "clauses": n_cl}
    model = solver.get_model()
    chosen = [i for i in range(n) if model[i] > 0]  # var i+1 in pos i
    out = {"status": "SAT", "m": m, "secs": round(dt, 1),
           "chosen_reps": [reps[i] for i in chosen],
           "margin": sum(d[i] for i in chosen),
           "F": 2 + sum(info[i][1] for i in chosen),
           "complete_model": (pair_filter == "all")}
    return out


if __name__ == "__main__":
    which = sys.argv[1]
    cap = int(sys.argv[2]) if len(sys.argv) > 2 else None
    def C(default):
        return cap if cap else default
    if which == "controls":
        for mm in (7, 11):
            r = decide(mm, wall_cap=60)
            print(f"  CONTROLLO pysat Z_{mm} (atteso UNSAT): {r}")
            assert r["status"].startswith("UNSAT"), "BUG pipeline pysat: fermarsi!"
        print("  [OK] pipeline pysat validata su Z_7, Z_11")
    elif which == "z13":
        r = decide(13, wall_cap=C(250))
        print(f"  Z_13 con pysat/CaDiCaL (atteso UNSAT, conferma indipendente): {r}")
    elif which == "z14":
        r = decide(14, wall_cap=C(250))
        print(f"  DECISIONE Z_14 (pysat, streaming): {r}")
        if r["status"] == "SAT":
            print("  !!! modello completo: candidato -> protocollo di verifica" if r.get("complete_model") else "")
    elif which == "z15":
        r = decide(15, wall_cap=C(250))
        print(f"  DECISIONE Z_15 (pysat, streaming): {r}")
    elif which == "z15neg":
        r = decide(15, wall_cap=C(250), pair_filter="neg")
        print(f"  DECISIONE Z_15 (rilassamento neg-pairs): {r}")
    if which == "z14min3":
        r = decide(14, wall_cap=C(2400), min_size=3)
        print(f"  DECISIONE Z_14, taglie>=3 (pysat, streaming): {r}")
    if which == "z13min3":
        r = decide(13, wall_cap=C(2400), min_size=3)
        print(f"  DECISIONE Z_13, taglie>=3 (pysat): {r}")
