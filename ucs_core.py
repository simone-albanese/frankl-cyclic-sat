"""ucs_core.py — Infrastruttura esatta per famiglie union-closed.

Rappresentazione: un insieme A ⊆ [m] è un intero (bitmask) su m bit.
Una famiglia è una lista/insieme di bitmask distinti.
TUTTA l'aritmetica dei verdetti è intera: la condizione di controesempio
è 2*max_freq < |F| (equivale a max_freq/|F| < 1/2 senza floating point).
"""

def popcount(x: int) -> int:
    return x.bit_count()


def rot(mask: int, k: int, m: int) -> int:
    """Rotazione ciclica di k posizioni su Z_m."""
    k %= m
    full = (1 << m) - 1
    return ((mask << k) | (mask >> (m - k))) & full


def canon(mask: int, m: int) -> int:
    """Rappresentante canonico dell'orbita ciclica: minimo su tutte le rotazioni."""
    return min(rot(mask, k, m) for k in range(m))


def closure(generators, cap=None):
    """Chiusura per unione dei generatori (bitmask). Restituisce frozenset di mask.
    NON include l'insieme vuoto (va aggiunto a parte se lo si vuole).
    BFS incrementale: nuovi = OR di un nuovo elemento con tutti i presenti.
    cap: se non None, abortisce (return None) se |F| supera cap."""
    fam = set()
    frontier = list(dict.fromkeys(generators))  # dedup, ordine stabile
    for g in frontier:
        fam.add(g)
    while frontier:
        new_frontier = []
        for b in frontier:
            for a in list(fam):
                u = a | b
                if u not in fam:
                    fam.add(u)
                    new_frontier.append(u)
                    if cap is not None and len(fam) > cap:
                        return None
        frontier = new_frontier
    return frozenset(fam)


def check_family(fam, m):
    """Checker n.1 (esatto, intero). fam: collezione di bitmask su [m].
    Restituisce dict con: ok_distinct, ok_nonempty_member, closed (bool),
    closure_violations (lista, max 3), F (=|fam|), freq (lista per elemento),
    maxf, margin (= 2*maxf - F, intero), is_counterexample (bool),
    is_tight (bool: margin == 0)."""
    fam = list(fam)
    F = len(fam)
    res = {"F": F}
    res["ok_distinct"] = (len(set(fam)) == F)
    res["ok_nonempty_member"] = any(x != 0 for x in fam)
    # chiusura su TUTTE le coppie (i<=j; i==j banale ma innocuo)
    s = set(fam)
    viol = []
    done = False
    for i in range(F):
        if done:
            break
        ai = fam[i]
        for j in range(i, F):
            u = ai | fam[j]
            if u not in s:
                viol.append((ai, fam[j], u))
                if len(viol) >= 3:  # bastano pochi witness
                    done = True
                    break
    res["closed"] = (len(viol) == 0)
    res["closure_violations"] = viol
    # frequenze per elemento (conteggio intero)
    freq = [0] * m
    for x in fam:
        y = x
        while y:
            b = (y & -y).bit_length() - 1
            freq[b] += 1
            y &= y - 1
    res["freq"] = freq
    maxf = max(freq) if freq else 0
    res["maxf"] = maxf
    res["margin"] = 2 * maxf - F  # intero; controesempio ⟺ margin <= -1
    res["is_counterexample"] = (
        res["ok_distinct"] and res["ok_nonempty_member"] and res["closed"]
        and 2 * maxf < F
    )
    res["is_tight"] = (res["closed"] and 2 * maxf == F)
    return res


def family_to_sets(fam, m):
    """Per stampa leggibile: bitmask -> tuple ordinate di elementi 0..m-1."""
    out = []
    for x in sorted(fam):
        s = tuple(i for i in range(m) if (x >> i) & 1)
        out.append(s)
    return out
