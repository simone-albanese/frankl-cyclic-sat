"""cyclic_enum.py — Enumerazione di famiglie union-closed cicliche-invarianti.

Per una famiglia F invariante sotto Z_m (transitiva) tutte le frequenze
coincidono: f = (somma delle taglie)/m. Condizione di controesempio:
2*sum_sizes < m*|F| (aritmetica intera). WLOG aggiungiamo sempre ∅.

Parte A: TUTTI i necklace non banali su Z_13 (esaustivo, 1 seme).
Parte B: idem su Z_14. Parte C: Z_15 parziale (taglie <= 6, con cap tempo).
Parte D: campione di coppie di semi su Z_13.
Nota: il caso 1-seme è coperto dal teorema di Aaronson–Ellis–Leader (2021);
qui funge da conferma sperimentale e da mappa del paesaggio dei margini.
"""
import sys, time, random
from ucs_core import rot, canon, closure, check_family, popcount

random.seed(1234)


def cyclic_orbit(mask, m):
    return {rot(mask, k, m) for k in range(m)}


def cyclic_closure_from_seeds(seeds, m):
    """Chiusura per unione dell'unione delle orbite cicliche dei semi."""
    gens = set()
    for s in seeds:
        gens |= cyclic_orbit(s, m)
    return closure(sorted(gens))


def analyze(fam, m, with_empty=True):
    """Restituisce (F, sum_sizes, margin_int) con ∅ aggiunto se richiesto.
    margin_int = 2*maxf - |F| ricavato SENZA float: per famiglie cicliche
    maxf = sum_sizes/m (verificato a parte), quindi margine su interi:
    m*margin = 2*sum_sizes - m*F."""
    F = len(fam) + (1 if with_empty and 0 not in fam else 0)
    ss = sum(popcount(x) for x in fam)
    # margine scalato: M_scaled = 2*ss - m*F  (controesempio ⟺ M_scaled <= -m... no: <= -1 basta, interi)
    return F, ss, 2 * ss - m * F


def necklaces(m, size_min=1, size_max=None):
    """Rappresentanti canonici delle orbite cicliche non banali su Z_m."""
    if size_max is None:
        size_max = m - 1
    seen = set()
    out = []
    for x in range(1, 1 << m):
        c = canon(x, m)
        if c in seen:
            continue
        seen.add(c)
        s = popcount(c)
        if size_min <= s <= size_max:
            out.append(c)
    return sorted(out)


def run_part(m, seeds_list, label, budget_s=None, verify_top=3):
    t0 = time.time()
    results = []  # (margin_scaled, F, ss, seed(s))
    done = 0
    for sd in seeds_list:
        if budget_s and time.time() - t0 > budget_s:
            break
        fam = cyclic_closure_from_seeds(sd if isinstance(sd, tuple) else (sd,), m)
        F, ss, M = analyze(fam, m)
        results.append((M, F, ss, sd))
        done += 1
    results.sort()
    print(f"\n== {label}: {done}/{len(seeds_list)} chiusure calcolate in {time.time()-t0:.1f}s ==")
    best = results[:10]
    for M, F, ss, sd in best:
        # frequenza comune f = ss/m; ratio = f/F stampato come frazione
        print(f"  margine_scalato(2*Σ|A|-m|F|)={M:>6}  |F|={F:>5}  Σ|A|={ss:>6}  f={ss}/{m}  seme={sd if isinstance(sd,tuple) else format(sd, 'b').zfill(m)}")
    n_counter = sum(1 for M, *_ in results if M <= -1)
    n_tight = sum(1 for M, *_ in results if M == 0)
    print(f"  candidati (margine<0): {n_counter} | famiglie tight (margine=0): {n_tight}")
    # verifica completa (checker1) delle migliori: frequenze davvero tutte uguali?
    from checker2 import verify
    from ucs_core import family_to_sets
    for M, F, ss, sd in best[:verify_top]:
        fam = cyclic_closure_from_seeds(sd if isinstance(sd, tuple) else (sd,), m)
        famE = set(fam) | {0}
        r1 = check_family(famE, m)
        assert r1["closed"], "chiusura fallita al checker!"
        assert len(set(r1["freq"])) == 1, f"frequenze non uniformi: {r1['freq']}"
        assert m * r1["margin"] == M, (m, r1["margin"], M)
        r2 = verify(family_to_sets(famE, m))
        assert r2["margin"] == r1["margin"] and r2["closed"]
    print(f"  [verifica checker1+2 su top-{min(verify_top,len(best))}: chiusura OK, frequenze uniformi OK, margini concordi]")
    return results


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"

    if which in ("all", "13"):
        seeds13 = necklaces(13, 1, 12)
        print(f"Z_13: {len(seeds13)} necklace non banali (attesi 630 = (2^13-2)/13)")
        assert len(seeds13) == (2**13 - 2) // 13 == 630
        run_part(13, seeds13, "Z_13 esaustivo 1-seme")

    if which in ("all", "14"):
        seeds14 = necklaces(14, 1, 13)
        print(f"\nZ_14: {len(seeds14)} necklace non banali")
        run_part(14, seeds14, "Z_14 esaustivo 1-seme", budget_s=150)

    if which in ("all", "15"):
        seeds15 = necklaces(15, 1, 6)
        print(f"\nZ_15: {len(seeds15)} necklace con taglia<=6 (copertura parziale dichiarata)")
        run_part(15, seeds15, "Z_15 parziale (taglie<=6)", budget_s=120)

    if which in ("all", "pairs"):
        base = necklaces(13, 2, 11)
        pairs = []
        while len(pairs) < 800:
            a, b = random.sample(base, 2)
            pairs.append((a, b))
        run_part(13, pairs, "Z_13 campione 800 coppie di semi", budget_s=150)
