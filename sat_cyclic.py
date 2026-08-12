"""sat_cyclic.py — Decisione esatta: esiste un controesempio Z_m-invariante?

Modello. Una famiglia union-closed invariante sotto lo shift ciclico di Z_m è
unione di orbite cicliche; WLOG contiene ∅ e (se non vuota) l'universo Z_m
(unione di tutti i traslati di qualunque seme non vuoto). Variabile booleana
x_O per ogni orbita non banale O (rappresentante canonico c, taglia orbita
r_O, taglia insieme s_O).

Conteggi (∅ e full sempre inclusi):
  |F| = 2 + Σ r_O x_O
  f (frequenza comune, uniforme per transitività) = 1 + (Σ r_O s_O x_O)/m
  margine M = 2f - |F| = Σ r_O (2 s_O - m) x_O / m   (∅ e full si cancellano)
Per m primo r_O = m e M = Σ (2 s_O - m) x_O. In generale usiamo il margine
scalato  m·M = Σ r_O (2 s_O - m) x_O  (intero; controesempio ⟺ m·M ≤ -m).

Chiusura: per ogni coppia di orbite (O1,O2), per invarianza basta fissare
A = rep(O1) e far variare B su tutta O2: clausola ¬x1 ∨ ¬x2 ∨ x_{orb(A∪B)}
per ogni unione che non sia full né in O1/O2 (in tal caso è già soddisfatta).

CONTROLLI PIPELINE: lo stesso codice su Z_7 e Z_11 DEVE dare INFEASIBLE
(la congettura è dimostrata per universi ≤ 12): se risultasse SAT c'è un
bug di encoding e ci si ferma.
"""
import sys, time
from ortools.sat.python import cp_model
from ucs_core import rot, popcount


def canon_table(m):
    full = (1 << m) - 1
    tab = [0] * (full + 1)
    for x in range(1, full + 1):
        if tab[x]:
            continue
        orb = []
        y = x
        c = x
        for k in range(m):
            y = rot(x, k, m)
            orb.append(y)
            if y < c:
                c = y
        for y in set(orb):
            tab[y] = c
    return tab


def build_orbits(m, tab):
    """Orbite non banali: rep canonico -> (index, r, s)."""
    full = (1 << m) - 1
    reps = sorted({tab[x] for x in range(1, full)})
    info = []
    idx = {}
    for i, c in enumerate(reps):
        orb = {rot(c, k, m) for k in range(m)}
        info.append((c, len(orb), popcount(c)))
        idx[c] = i
    return reps, info, idx


def build_clauses(m, tab, reps, info, idx):
    full = (1 << m) - 1
    n = len(reps)
    orbits_sets = []
    for c, r, s in info:
        orbits_sets.append(sorted({rot(c, k, m) for k in range(m)}))
    clauses = []  # (i, j, t) -> ¬xi ∨ ¬xj ∨ xt
    t0 = time.time()
    for i in range(n):
        A = reps[i]
        for j in range(i, n):
            targets = set()
            for B in orbits_sets[j]:
                u = A | B
                if u == full:
                    continue
                cu = tab[u]
                targets.add(cu)
            targets.discard(reps[i])
            targets.discard(reps[j])
            for cu in targets:
                clauses.append((i, j, idx[cu]))
    return clauses, time.time() - t0


def solve(m, mode="decide", time_cap=120, verbose=True, min_set_size=1):
    tab = canon_table(m)
    reps, info, idx = build_orbits(m, tab)
    n = len(reps)
    clauses, tb = build_clauses(m, tab, reps, info, idx)
    if verbose:
        print(f"  Z_{m}: {n} orbite non banali, {len(clauses)} clausole di chiusura (build {tb:.1f}s)")
    model = cp_model.CpModel()
    x = [model.NewBoolVar(f"x{i}") for i in range(n)]
    if min_set_size > 1:
        for i, (_, r, s) in enumerate(info):
            if s < min_set_size:
                model.Add(x[i] == 0)
    for i, j, t in clauses:
        model.AddBoolOr([x[i].Not(), x[j].Not(), x[t]])
    # margine scalato m*M = Σ r(2s-m) x  (intero)
    coeff = [r * (2 * s - m) for (_, r, s) in info]
    expr = sum(c * xi for c, xi in zip(coeff, x))
    model.Add(sum(x) >= 1)  # esclude la famiglia banale {∅, Z_m}
    if mode == "decide":
        model.Add(expr <= -m)  # M <= -1
    else:
        obj = model.NewIntVar(-sum(abs(c) for c in coeff), sum(abs(c) for c in coeff), "M")
        model.Add(obj == expr)
        model.Minimize(obj)
    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = time_cap
    solver.parameters.num_search_workers = 4
    st = solver.Solve(model)
    name = solver.StatusName(st)
    out = {"status": name, "m": m}
    if st in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        chosen = [i for i in range(n) if solver.Value(x[i])]
        out["chosen_reps"] = [reps[i] for i in chosen]
        out["scaled_margin"] = sum(coeff[i] for i in chosen)
        out["F"] = 2 + sum(info[i][1] for i in chosen)
    return out


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "controls"
    if which == "controls":
        for mm in (7, 11):
            t0 = time.time()
            r = solve(mm, "decide", time_cap=60)
            print(f"  CONTROLLO Z_{mm} (atteso INFEASIBLE): {r['status']}  [{time.time()-t0:.1f}s]")
            assert r["status"] == "INFEASIBLE", f"BUG DI ENCODING su Z_{mm}: fermarsi!"
        print("  [OK] pipeline SAT validata: nessun controesempio ciclico su Z_7, Z_11 (come da teoria)")
    elif which == "decide13":
        t0 = time.time()
        r = solve(13, "decide", time_cap=150)
        print(f"  DECISIONE Z_13, vincolo M<=-1: {r['status']}  [{time.time()-t0:.1f}s]")
        if r["status"] in ("FEASIBLE", "OPTIMAL"):
            print("  !!! CANDIDATO TROVATO:", r)
    elif which == "opt13":
        t0 = time.time()
        r = solve(13, "optimize", time_cap=180)
        print(f"  OTTIMIZZAZIONE Z_13 (min M): {r['status']}  [{time.time()-t0:.1f}s]")
        if "scaled_margin" in r:
            print(f"  margine minimo m*M = {r['scaled_margin']}  (M = {r['scaled_margin']//13})  |F| = {r['F']}")
            print(f"  orbite scelte (rep canonici): {r['chosen_reps']}")
    elif which == "opt13min3":
        t0 = time.time()
        r = solve(13, "optimize", time_cap=200, min_set_size=3)
        print(f"  OTTIMIZZAZIONE Z_13, taglie>=3 (min M): {r['status']}  [{time.time()-t0:.1f}s]")
        if "scaled_margin" in r:
            M = r["scaled_margin"] // 13
            print(f"  margine minimo M = {M}  |F| = {r['F']}  (f = {(r['F'] + M) // 2})")
            print(f"  orbite scelte: {len(r['chosen_reps'])}  rep: {r['chosen_reps'][:20]}{'...' if len(r['chosen_reps'])>20 else ''}")
    elif which == "decide14":
        t0 = time.time()
        r = solve(14, "decide", time_cap=150)
        print(f"  DECISIONE Z_14, vincolo M<=-1: {r['status']}  [{time.time()-t0:.1f}s]")
        if r["status"] in ("FEASIBLE", "OPTIMAL"):
            print("  !!! CANDIDATO TROVATO:", r)
