"""structured.py — Costruzioni strutturate su 13 punti, con verifiche a mano.

Ogni costruzione ha conteggi ATTESI calcolati a mano prima del run: se il
codice non li riproduce, il bug è nel codice (o nel conto, da rifare a mano).
"""
import time
from fractions import Fraction
from ucs_core import closure, check_family, family_to_sets, rot, popcount
from checker2 import verify


def report(name, gens, m, expected=None):
    fam = set(closure(gens)) | {0}
    r1 = check_family(fam, m)
    r2 = verify(family_to_sets(fam, m))
    assert r1["closed"] and r2["closed"]
    assert r1["margin"] == r2["margin"] and r1["maxf"] == r2["maxf"]
    F, maxf, marg = r1["F"], r1["maxf"], r1["margin"]
    ratio = Fraction(maxf, F)
    sizes = {}
    for x in fam:
        sizes[popcount(x)] = sizes.get(popcount(x), 0) + 1
    print(f"== {name}: |F|={F} (con ∅), maxf={maxf}, margine={marg}, ratio={ratio} ≈ {float(ratio):.4f}")
    print(f"   distribuzione taglie: {dict(sorted(sizes.items()))}")
    if expected:
        for k, v in expected.items():
            got = {"F": F, "maxf": maxf, "margin": marg}.get(k, sizes.get(k))
            assert got == v, f"{name}: atteso {k}={v}, ottenuto {got} — BUG da trovare"
        print(f"   [assert a mano superati: {expected}]")
    assert marg >= 0 or (print('CANDIDATO!!', name) or True)
    return marg, F, ratio


# ---------- 1) Piano proiettivo PG(2,3): 13 punti, 13 rette da 4 punti ----------
def pg23_lines():
    # punti proiettivi su GF(3): rappresentanti normalizzati (primo coeff non nullo = 1)
    pts = []
    for x in range(3):
        for y in range(3):
            for z in range(3):
                if (x, y, z) == (0, 0, 0):
                    continue
                # normalizza: primo coefficiente non nullo -> 1
                v = (x, y, z)
                for c in v:
                    if c != 0:
                        inv = 1 if c == 1 else 2  # inverso in GF(3)
                        v = tuple((inv * t) % 3 for t in v)
                        break
                if v not in pts:
                    pts.append(v)
    assert len(pts) == 13
    idx = {p: i for i, p in enumerate(pts)}
    lines = []
    for a, b, c in pts:  # ogni retta = punti ortogonali a un punto duale
        mask = 0
        for p in pts:
            if (a * p[0] + b * p[1] + c * p[2]) % 3 == 0:
                mask |= 1 << idx[p]
        assert popcount(mask) == 4
        lines.append(mask)
    assert len(set(lines)) == 13
    return lines


# ---------- 2) STS(13) ciclico: blocchi base {0,1,4}, {0,2,7} ----------
def sts13_blocks():
    base = [(0, 1, 4), (0, 2, 7)]
    blocks = []
    for b in base:
        for k in range(13):
            blocks.append(frozenset((x + k) % 13 for x in b))
    blocks = sorted(set(blocks))
    assert len(blocks) == 26
    # verifica Steiner: ogni coppia esattamente una volta
    from itertools import combinations
    seen = {}
    for B in blocks:
        for p in combinations(sorted(B), 2):
            seen[p] = seen.get(p, 0) + 1
    assert all(v == 1 for v in seen.values()) and len(seen) == 78, "non è un STS(13)!"
    return [sum(1 << i for i in B) for B in blocks]


# ---------- 3) Residui quadratici mod 13 ----------
def qr13_orbit():
    qr = {(i * i) % 13 for i in range(1, 13)}
    assert qr == {1, 3, 4, 9, 10, 12}
    mask = sum(1 << i for i in qr)
    return [rot(mask, k, 13) for k in range(13)]


# ---------- 4) Intervalli ciclici: chiusura di {0,1,2} su Z13 ----------
def runs3_gens():
    mask = 0b111
    return [rot(mask, k, 13) for k in range(13)]


if __name__ == "__main__":
    t0 = time.time()
    results = []
    results.append(("PG(2,3)", report(
        "PG(2,3) chiusura delle 13 rette", pg23_lines(), 13,
        expected={"F": 704, "maxf": 507, "margin": 310, 4: 13, 7: 78, 9: 234,
                  10: 286, 11: 78, 12: 13, 13: 1})))
    results.append(("STS(13)", report("STS(13) ciclico {0,1,4},{0,2,7}", sts13_blocks(), 13)))
    results.append(("QR(13)", report("QR(13) orbita di {1,3,4,9,10,12}", qr13_orbit(), 13)))
    results.append(("Runs>=3", report(
        "Intervalli: chiusura ciclica di {0,1,2}", runs3_gens(), 13,
        expected={"F": 522})))
    print(f"\nTutte le costruzioni verificate in {time.time()-t0:.1f}s")
    best = min(results, key=lambda r: (r[1][0], -r[1][1]))
    print(f"Migliore strutturata: {best[0]} con margine {best[1][0]} (ratio ≈ {float(best[1][2]):.4f})")
    print("\nNota up-set (esclusi a priori): per ogni up-set U e ogni x, la mappa"
          " S ↦ S∪{x} è un'iniezione dai membri senza x ai membri con x,"
          " quindi ogni elemento ha frequenza ≥ |U|/2: mai competitivi.")
