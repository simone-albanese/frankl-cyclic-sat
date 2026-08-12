#!/usr/bin/env python3
"""T9 — Sonda costi Z15 (taglie >= 3): orbite, clausole, RAM di picco, tempi.
Come probe_z14.py ma con m=15 (non primo: r_O in {1,3,5,15}); il margine
scalato di sat_cyclic (m*M = sum r_O(2s_O-m)x_O <= -m) resta intero per
costruzione. Costruisce il CpModel completo ma NON chiama Solve. In piu'
stampa la distribuzione dei periodi r_O come sanity-check sul caso non primo."""
import os
import resource
import sys
import time
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from sat_cyclic import canon_table, build_orbits, build_clauses
from ortools.sat.python import cp_model

M = 15
MIN_SET_SIZE = 3


def rss_gb():
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / (1024 ** 3)


t0 = time.time()
tab = canon_table(M)
print(f"canon_table: {time.time()-t0:.1f}s, RSS {rss_gb():.2f} GB", flush=True)

t0 = time.time()
reps, info, idx = build_orbits(M, tab)
n = len(reps)
print(f"n_orbite = {n} ({time.time()-t0:.1f}s), RSS {rss_gb():.2f} GB", flush=True)
periodi = Counter(r for (_, r, s) in info)
print(f"periodi r_O = {dict(sorted(periodi.items()))}", flush=True)
sanity = set(periodi) <= {1, 3, 5, 15}
print(f"sanity periodi in {{1,3,5,15}}: {'OK' if sanity else 'FAIL'}", flush=True)

clauses, tb = build_clauses(M, tab, reps, info, idx)
print(f"n_clausole = {len(clauses)} (build {tb:.1f}s), RSS {rss_gb():.2f} GB", flush=True)

t0 = time.time()
model = cp_model.CpModel()
x = [model.NewBoolVar(f"x{i}") for i in range(n)]
for i, (_, r, s) in enumerate(info):
    if s < MIN_SET_SIZE:
        model.Add(x[i] == 0)
for i, j, t in clauses:
    model.AddBoolOr([x[i].Not(), x[j].Not(), x[t]])
coeff = [r * (2 * s - M) for (_, r, s) in info]
expr = sum(c * xi for c, xi in zip(coeff, x))
model.Add(sum(x) >= 1)
model.Add(expr <= -M)
print(f"CpModel costruito: {time.time()-t0:.1f}s", flush=True)
print(f"RSS_modello = {rss_gb():.2f} GB", flush=True)
print("PROBE OK (nessun Solve eseguito)", flush=True)
