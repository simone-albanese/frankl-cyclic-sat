"""anneal.py — Ricerca locale (simulated annealing) sui generatori.

Stato: k generatori (bitmask) su [m]. Energia: rapporto maxf/|F| della
chiusura (float SOLO come guida del campionamento; ogni verdetto e il best
globale usano il margine intero 2*maxf-|F|). Mosse: flip di un bit di un
generatore, oppure sostituzione di un generatore con uno casuale.

Modalità A (libera): attrattore atteso il power set su k singleton
(margine 0, tight, banale) — un restart vi viene seminato apposta come
calibrazione. Modalità B (vincolata): ogni generatore ha taglia >= 3
(un controesempio non può contenere insiemi di taglia 1 o 2, quindi la
regione rilevante è questa); attrattori attesi: power set "a blocchi".
"""
import random, time
from fractions import Fraction
from ucs_core import closure, check_family, popcount

random.seed(42)


def energy(gens, m, cap=6000):
    fam = closure(gens, cap=cap)
    if fam is None:
        return None, None, None
    famE = set(fam) | {0}
    F = len(famE)
    freq = [0] * m
    for x in famE:
        y = x
        while y:
            b = (y & -y).bit_length() - 1
            freq[b] += 1
            y &= y - 1
    maxf = max(freq)
    return 2 * maxf - F, F, maxf  # margine intero


def rand_gen(m, min_size):
    while True:
        g = random.randint(1, (1 << m) - 1)
        if popcount(g) >= min_size:
            return g


def flip_ok(g, m, min_size):
    b = 1 << random.randrange(m)
    g2 = g ^ b
    if g2 == 0 or popcount(g2) < min_size:
        return g
    return g2


def anneal(m, k, min_size, iters=2500, T0=0.08, T1=0.002, seed_state=None):
    gens = seed_state[:] if seed_state else [rand_gen(m, min_size) for _ in range(k)]
    cur = energy(gens, m)
    while cur[0] is None:
        gens = [rand_gen(m, min_size) for _ in range(k)]
        cur = energy(gens, m)
    best = (cur, gens[:])
    for it in range(iters):
        T = T0 * (T1 / T0) ** (it / iters)
        cand = gens[:]
        if random.random() < 0.7:
            i = random.randrange(k)
            cand[i] = flip_ok(cand[i], m, min_size)
        else:
            cand[random.randrange(k)] = rand_gen(m, min_size)
        e2 = energy(cand, m)
        if e2[0] is None:
            continue
        # guida float: ratio = maxf/F
        r_cur = cur[2] / cur[1]
        r_new = e2[2] / e2[1]
        if r_new <= r_cur or random.random() < pow(2.718281828, -(r_new - r_cur) / T):
            gens, cur = cand, e2
            if (cur[0], -cur[1]) < (best[0][0], -best[0][1]):
                best = (cur, gens[:])
    return best


def run_mode(label, m_list, min_size, budget_s, seed_powerset=False):
    t0 = time.time()
    global_best = None  # (margine, -F, ratioFrac, gens, m)
    tried = 0
    for m in m_list:
        for k in (6, 8, 10, 12):
            if time.time() - t0 > budget_s:
                break
            restarts = 3
            for r in range(restarts):
                if time.time() - t0 > budget_s:
                    break
                seed = None
                if seed_powerset and r == 0 and min_size == 1:
                    seed = [1 << i for i in range(k)]  # calibrazione: power set
                (marg, F, maxf), gens = anneal(m, k, min_size, seed_state=seed)
                tried += 1
                key = (marg, -F)
                if global_best is None or key < (global_best[0], -global_best[1]):
                    global_best = (marg, F, Fraction(maxf, F), gens, m)
    marg, F, ratio, gens, m = global_best
    print(f"== {label}: {tried} run in {time.time()-t0:.0f}s ==")
    print(f"  miglior margine intero = {marg} (F={F}, ratio esatto = {ratio} ≈ {float(ratio):.6f}, m={m})")
    print(f"  generatori: {[format(g, 'b').zfill(m) for g in gens]}")
    # doppia verifica del best
    fam = set(closure(gens)) | {0}
    r1 = check_family(fam, m)
    from checker2 import verify
    from ucs_core import family_to_sets
    r2 = verify(family_to_sets(fam, m))
    assert r1["margin"] == marg == r2["margin"] and r1["closed"] and r2["closed"]
    print(f"  [checker1+2 concordi: chiusa, margine {marg}]")
    if marg <= -1:
        print("  !!! CANDIDATO: fermarsi e attivare protocollo di verifica completo")
    return global_best


if __name__ == "__main__":
    import sys
    mode = sys.argv[1] if len(sys.argv) > 1 else "A"
    if mode == "A":
        run_mode("Modalità A (libera, min_size=1)", (13, 14), 1, budget_s=110, seed_powerset=True)
    else:
        run_mode("Modalità B (vincolata, min_size=3)", (13, 14, 15, 16), 3, budget_s=200)
