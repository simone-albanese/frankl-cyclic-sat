"""controls.py — Controlli obbligatori del protocollo (eseguire PRIMA di ogni run).

1) Controllo negativo: insieme delle parti di [4] -> maxf ESATTAMENTE |F|/2.
2) Controllo positivo (validatore): {{0},{1}} senza {0,1} deve essere RIFIUTATO.
3) Controllo positivo (detector): input artificiale con tutte le frequenze
   sotto la metà deve far scattare il confronto 2*maxf < |F| (pur non essendo
   chiuso: il verdetto complessivo deve restare False).
4) Accordo checker1/checker2 su chiusure casuali piccole.
"""
import random
from ucs_core import closure, check_family, family_to_sets
from checker2 import verify

random.seed(20260810)
FAIL = []

# ---- 1) Controllo negativo: P([4]) \ {∅} con ∅ aggiunto = P([4]) intero ----
m = 4
power = [x for x in range(0, 1 << m)]  # 16 insiemi, ∅ incluso
r1 = check_family(power, m)
r2 = verify(family_to_sets(power, m))
assert r1["F"] == 16 and r2["F"] == 16
assert r1["closed"] and r2["closed"]
assert r1["maxf"] == 8 and r2["maxf"] == 8
assert 2 * r1["maxf"] == r1["F"], "P([4]): atteso maxf esattamente |F|/2"
assert r1["margin"] == 0 and r2["margin"] == 0
assert not r1["is_counterexample"] and not r2["is_counterexample"]
assert r1["is_tight"]
print("[OK] controllo negativo P([4]): |F|=16, maxf=8, margine=0, tight, NON controesempio")

# ---- 2) Validatore rifiuta famiglia non chiusa ----
bad = [0b01, 0b10]  # {0},{1}: manca {0,1}
r1 = check_family(bad, 2)
r2 = verify([[0], [1]])
assert not r1["closed"] and not r2["closed"]
assert not r1["is_counterexample"] and not r2["is_counterexample"]
print("[OK] validatore: {{0},{1}} rifiutata (manca {0,1}); violazione:", r1["closure_violations"][:1])

# ---- 3) Detector frequenze scatta su input artificiale ----
sing = [1 << i for i in range(6)]  # sei singleton su [6]
r1 = check_family(sing, 6)
r2 = verify([[i] for i in range(6)])
assert r1["maxf"] == 1 and r1["F"] == 6 and 2 * r1["maxf"] < r1["F"], "detector deve scattare"
assert r2["margin"] == 2 * 1 - 6 == -4
assert not r1["closed"], "sei singleton non sono chiusi per unione"
assert not r1["is_counterexample"], "verdetto complessivo deve restare False (chiusura violata)"
print("[OK] detector frequenze: 2*maxf=2 < |F|=6 rilevato; verdetto finale correttamente False (non chiusa)")

# ---- 4) Accordo checker1 vs checker2 su 50 chiusure casuali ----
agree = 0
for t in range(50):
    mm = 10
    k = random.randint(2, 6)
    gens = [random.randint(1, (1 << mm) - 1) for _ in range(k)]
    fam = closure(gens)
    fam_with_empty = set(fam) | {0}
    a = check_family(fam_with_empty, mm)
    b = verify(family_to_sets(fam_with_empty, mm))
    assert a["F"] == b["F"] and a["maxf"] == b["maxf"] and a["margin"] == b["margin"]
    assert a["closed"] and b["closed"], "una chiusura deve risultare chiusa per entrambi"
    assert a["is_counterexample"] == b["is_counterexample"]
    agree += 1
print(f"[OK] accordo checker1/checker2 su {agree}/50 chiusure casuali (m=10, k<=6)")

# ---- 5) Sanity chiusura: closure() produce davvero famiglie chiuse ----
for t in range(10):
    gens = [random.randint(1, (1 << 8) - 1) for _ in range(4)]
    fam = closure(gens)
    r = check_family(fam, 8)
    assert r["closed"]
print("[OK] closure(): 10/10 famiglie generate risultano chiuse al checker")

print("\nTUTTI I CONTROLLI SUPERATI")
