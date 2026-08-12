"""cegar.py — Decisione CEGAR: esiste un controesempio Z_m-invariante?

Idea. Il modello monolitico (sat_cyclic) satura la memoria per m=14 (7,3M
clausole). Qui si parte dal SOLO vincolo di margine (rilassamento) e si
aggiungono le clausole di chiusura solo quando violate da una soluzione
candidata (counterexample-guided refinement).

Garanzie. Se il rilassato è INFEASIBLE, lo è anche il problema completo
(abbiamo solo tolto vincoli) → risposta definitiva. Se una soluzione
soddisfa TUTTE le chiusure (scansione completa senza violazioni), è un
candidato reale → protocollo di stop e doppia verifica. Terminazione:
pool di clausole finito, ogni iterazione ne aggiunge almeno una.

Seeding. Le orbite a coefficiente negativo (2s < m) sono quelle che ogni
soluzione deve usare: pre-carichiamo le clausole tra coppie di tali orbite
(in ordine di s crescente) fino a un budget, per abbattere le iterazioni.

CONTROLLI: Z_7 e Z_11 devono dare INFEASIBLE; Z_13 deve CONCORDARE con il
risultato monolitico (INFEASIBLE). Solo dopo si passa a Z_14, Z_15.
"""
import sys, time
from ortools.sat.python import cp_model
from ucs_core import rot
from sat_cyclic import canon_table, build_orbits


def cegar_decide(m, wall_cap=240, seed_budget=1_200_000, iter_cap=300,
                 per_solve_cap=90, verbose=True):
    t0 = time.time()
    tab = canon_table(m)
    reps, info, idx = build_orbits(m, tab)
    n = len(reps)
    full = (1 << m) - 1
    orbit_sets = [sorted({rot(c, k, m) for k in range(m)}) for c, _, _ in info]
    coeff = [r * (2 * s - m) for (_, r, s) in info]  # margine scalato m*M

    model = cp_model.CpModel()
    x = [model.NewBoolVar(f"x{i}") for i in range(n)]
    model.Add(sum(c * xi for c, xi in zip(coeff, x)) <= -m)  # M <= -1
    model.Add(sum(x) >= 1)

    added = set()

    def clauses_for_pair(i, j):
        A = reps[i]
        out = set()
        for B in orbit_sets[j]:
            u = A | B
            if u == full:
                continue
            t = idx[tab[u]]
            if t == i or t == j:
                continue
            out.add((i, j, t))
        return out

    def add_clause(cl):
        i, j, t = cl
        model.AddBoolOr([x[i].Not(), x[j].Not(), x[t]])
        added.add(cl)

    # ---- seeding: coppie tra orbite a coefficiente negativo, s crescente ----
    neg = sorted((i for i in range(n) if coeff[i] < 0), key=lambda i: info[i][2])
    seeded = 0
    done_seed = False
    for a in range(len(neg)):
        if done_seed:
            break
        for b in range(a, len(neg)):
            i, j = neg[a], neg[b]
            for cl in clauses_for_pair(i, j):
                if cl not in added:
                    add_clause(cl)
                    seeded += 1
            if seeded > seed_budget:
                done_seed = True
                break
    if verbose:
        print(f"  Z_{m}: {n} orbite; seeding {seeded} clausole "
              f"(coppie tra {len(neg)} orbite a coeff<0) in {time.time()-t0:.1f}s")

    solver = cp_model.CpSolver()
    solver.parameters.num_search_workers = 4

    for it in range(1, iter_cap + 1):
        remaining = wall_cap - (time.time() - t0)
        if remaining < 5:
            return {"status": "UNKNOWN(wall-cap)", "iters": it - 1,
                    "clauses": len(added), "m": m}
        solver.parameters.max_time_in_seconds = min(per_solve_cap, remaining)
        st = solver.Solve(model)
        name = solver.StatusName(st)
        if st == cp_model.INFEASIBLE:
            return {"status": "INFEASIBLE", "iters": it,
                    "clauses": len(added), "m": m,
                    "secs": round(time.time() - t0, 1)}
        if st not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
            return {"status": f"UNKNOWN({name})", "iters": it,
                    "clauses": len(added), "m": m}
        S = [i for i in range(n) if solver.Value(x[i])]
        # cerca violazioni di chiusura nella soluzione candidata
        viol = set()
        capped = False
        for a in range(len(S)):
            for b in range(a, len(S)):
                new = clauses_for_pair(S[a], S[b]) - added
                viol |= new
                if len(viol) > 50_000:
                    capped = True
                    break
            if capped:
                break
        if not viol and not capped:
            # scansione COMPLETA senza violazioni: candidato reale
            return {"status": "SAT-CANDIDATE", "iters": it, "m": m,
                    "chosen_reps": [reps[i] for i in S],
                    "scaled_margin": sum(coeff[i] for i in S),
                    "F": 2 + sum(info[i][1] for i in S)}
        for cl in viol:
            add_clause(cl)
        if verbose and (it <= 3 or it % 10 == 0):
            print(f"    iter {it}: |S|={len(S)}, +{len(viol)} clausole "
                  f"(tot {len(added)}), t={time.time()-t0:.0f}s")
    return {"status": "UNKNOWN(iter-cap)", "iters": iter_cap,
            "clauses": len(added), "m": m}


if __name__ == "__main__":
    which = sys.argv[1]
    if which == "controls":
        for mm in (7, 11):
            r = cegar_decide(mm, wall_cap=90, seed_budget=200_000, verbose=True)
            print(f"  CONTROLLO CEGAR Z_{mm} (atteso INFEASIBLE): {r}")
            assert r["status"] == "INFEASIBLE", "BUG nella pipeline CEGAR: fermarsi!"
        print("  [OK] pipeline CEGAR validata su Z_7, Z_11")
    elif which == "cross13":
        r = cegar_decide(13, wall_cap=240, seed_budget=900_000)
        print(f"  CROSS-CHECK CEGAR Z_13 (atteso INFEASIBLE come il monolitico): {r}")
        assert r["status"] == "INFEASIBLE", "DISACCORDO col monolitico: indagare!"
    elif which == "z14":
        r = cegar_decide(14, wall_cap=250, seed_budget=1_200_000)
        print(f"  DECISIONE CEGAR Z_14: {r}")
        if r["status"] == "SAT-CANDIDATE":
            print("  !!! CANDIDATO: attivare protocollo di verifica completo")
    elif which == "z15":
        r = cegar_decide(15, wall_cap=250, seed_budget=1_200_000)
        print(f"  DECISIONE CEGAR Z_15: {r}")
        if r["status"] == "SAT-CANDIDATE":
            print("  !!! CANDIDATO: attivare protocollo di verifica completo")
