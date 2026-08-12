"""dump_dimacs.py — Scrive in DIMACS la formula 'controesempio Z_m-invariante'.

Riusa ESATTAMENTE le stesse funzioni della pipeline pysat validata
(canon_table/build_orbits di sat_cyclic, encode_signed_leq di pb_adder):
la formula certificata è per costruzione quella già decisa in-process.
Uso: python3 dump_dimacs.py <m> <out.cnf> [min_size]
"""
import sys
from ucs_core import rot
from sat_cyclic import canon_table, build_orbits
from pb_adder import Pool, encode_signed_leq


def dump(m, path, min_size=1):
    tab = canon_table(m)
    reps, info, idx = build_orbits(m, tab)
    n = len(reps)
    full = (1 << m) - 1
    orbit_sets = [sorted({rot(c, k, m) for k in range(m)}) for c, _, _ in info]
    d = []
    for (_, r, s) in info:
        assert (2 * r * s) % m == 0
        d.append((2 * r * s) // m - r)
    pool = Pool(n + 1)
    pb = encode_signed_leq({i + 1: d[i] for i in range(n) if d[i] != 0}, -1, pool)
    ncl = 0
    body = path + ".body"
    with open(body, "w") as f:
        if min_size > 1:
            for i in range(n):
                if info[i][2] < min_size:
                    f.write(f"{-(i+1)} 0\n"); ncl += 1
        for c in pb:
            f.write(" ".join(map(str, c)) + " 0\n"); ncl += 1
        f.write(" ".join(str(v) for v in range(1, n + 1)) + " 0\n"); ncl += 1
        for i in range(n):
            Ai = reps[i]
            for j in range(i, n):
                seen = set()
                for B in orbit_sets[j]:
                    u = Ai | B
                    if u == full:
                        continue
                    t = idx[tab[u]]
                    if t == i or t == j or t in seen:
                        continue
                    seen.add(t)
                    f.write(f"{-(i+1)} {-(j+1)} {t+1} 0\n"); ncl += 1
    with open(path, "w") as f:
        f.write(f"p cnf {pool.next - 1} {ncl}\n")
    import subprocess
    subprocess.run(f"cat {body} >> {path} && rm {body}", shell=True, check=True)
    print(f"DIMACS: {path}  vars={pool.next - 1}  clauses={ncl}  (m={m}, min_size={min_size})")


if __name__ == "__main__":
    m = int(sys.argv[1]); out = sys.argv[2]
    ms = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    dump(m, out, ms)
