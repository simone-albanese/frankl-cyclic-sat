"""checker2.py — Verificatore INDIPENDENTE (implementazione n.2).

Scritto separatamente da ucs_core: usa frozenset di interi (elementi) e
collections.Counter, niente bitmask. Serve per il controllo incrociato
richiesto dal protocollo. Input: iterabile di iterabili di elementi.
"""
from collections import Counter
from itertools import combinations_with_replacement


def verify(family_of_sets):
    fam = [frozenset(s) for s in family_of_sets]
    n_sets = len(fam)
    report = {"F": n_sets}
    report["distinct"] = (len(set(fam)) == n_sets)
    report["has_nonempty"] = any(len(s) > 0 for s in fam)
    pool = set(fam)
    closed = True
    bad = None
    for a, b in combinations_with_replacement(fam, 2):
        if (a | b) not in pool:
            closed = False
            bad = (sorted(a), sorted(b))
            break
    report["closed"] = closed
    report["closure_witness_failure"] = bad
    cnt = Counter()
    for s in fam:
        cnt.update(s)
    report["freq"] = dict(cnt)
    mx = max(cnt.values()) if cnt else 0
    report["maxf"] = mx
    report["margin"] = 2 * mx - n_sets
    report["is_counterexample"] = (
        report["distinct"] and report["has_nonempty"] and closed
        and 2 * mx < n_sets
    )
    return report
