"""pb_adder.py — Vincolo pseudo-Booleano  Σ w_i · lit_i ≤ K  in CNF.

Encoding "adder network" (Warners): ogni termine contribuisce il proprio
peso in binario (bit = literal se il bit di w è 1, altrimenti costante 0);
i numeri si sommano a coppie in un albero bilanciato con full-adder
(Tseitin); il totale S (in binario) si confronta con la costante K con la
codifica lessicografica standard:
    per ogni posizione j con K_j = 0:  (¬S_j ∨ ⋁_{i>j, K_i=1} ¬S_i)
Correttezza del comparatore: S > K ⟺ alla posizione più alta p in cui
differiscono vale S_p=1, K_p=0 e S_i=K_i per i>p — esattamente il pattern
proibito dalla clausola in j=p; viceversa se S ≤ K ogni clausola è
soddisfatta dal primo bit più alto con K=1, S=0.

I bit costanti-0 sono rappresentati da None e semplificati ovunque.
Prima dell'uso in produzione: validate() confronta l'encoder con la forza
bruta su istanze casuali (entrambe le direzioni, via assunzioni SAT).
"""
import random


class Pool:
    def __init__(self, start):
        self.next = start  # prossima variabile libera (int >= 1)

    def new(self):
        v = self.next
        self.next += 1
        return v


def _xor2(a, b, pool, cls):
    s = pool.new()
    cls += [[a, b, -s], [a, -b, s], [-a, b, s], [-a, -b, -s]]
    return s

def _and2(a, b, pool, cls):
    t = pool.new()
    cls += [[-a, -b, t], [a, -t], [b, -t]]
    return t

def _xor3(a, b, c, pool, cls):
    s = pool.new()
    cls += [[a, b, c, -s], [a, b, -c, s], [a, -b, c, s], [-a, b, c, s],
            [a, -b, -c, -s], [-a, b, -c, -s], [-a, -b, c, -s], [-a, -b, -c, s]]
    return s

def _maj3(a, b, c, pool, cls):
    t = pool.new()
    cls += [[-a, -b, t], [-a, -c, t], [-b, -c, t],
            [a, b, -t], [a, c, -t], [b, c, -t]]
    return t


def _add_numbers(A, B, pool, cls):
    """Somma binaria (liste LSB-first di literal|None). Ritorna lista bit."""
    out = []
    carry = None
    for k in range(max(len(A), len(B))):
        bits = [z for z in (A[k] if k < len(A) else None,
                            B[k] if k < len(B) else None, carry) if z is not None]
        if not bits:
            out.append(None); carry = None
        elif len(bits) == 1:
            out.append(bits[0]); carry = None
        elif len(bits) == 2:
            out.append(_xor2(bits[0], bits[1], pool, cls))
            carry = _and2(bits[0], bits[1], pool, cls)
        else:
            out.append(_xor3(*bits, pool, cls))
            carry = _maj3(*bits, pool, cls)
    if carry is not None:
        out.append(carry)
    return out


def encode_leq(units, K, pool):
    """units: lista (literal, peso>0). Vincolo Σ peso·[lit vero] ≤ K (K≥0).
    Ritorna lista di clausole (da aggiungere al solver)."""
    cls = []
    if K < 0:
        return [[]]  # insoddisfacibile
    nums = []
    for lit, w in units:
        assert w > 0
        bits = []
        k = 0
        while (1 << k) <= w:
            bits.append(lit if (w >> k) & 1 else None)
            k += 1
        nums.append(bits)
    if not nums:
        return cls  # somma 0 <= K
    while len(nums) > 1:  # albero bilanciato
        nxt = []
        for i in range(0, len(nums) - 1, 2):
            nxt.append(_add_numbers(nums[i], nums[i + 1], pool, cls))
        if len(nums) % 2:
            nxt.append(nums[-1])
        nums = nxt
    S = nums[0]
    L = max(len(S), K.bit_length())
    S = S + [None] * (L - len(S))
    for j in range(L):
        if (K >> j) & 1 or S[j] is None:
            continue
        clause = [-S[j]]
        skip = False
        for i in range(j + 1, L):
            if (K >> i) & 1:
                if S[i] is None:      # S_i=0 ≠ K_i=1: pattern impossibile
                    skip = True; break
                clause.append(-S[i])
        if not skip:
            cls.append(clause)
    return cls


def encode_signed_leq(coeffs_by_var, bound, pool):
    """Σ d_v · x_v ≤ bound, d anche negativi; x_v = variabile v (int ≥ 1).
    Trasformazione: Σ_{d>0} d·x + Σ_{d<0} |d|·(¬x) ≤ bound + Σ_{d<0}|d|."""
    units = []
    Wneg = 0
    for v, d in coeffs_by_var.items():
        if d > 0:
            units.append((v, d))
        elif d < 0:
            units.append((-v, -d))
            Wneg += -d
    return encode_leq(units, bound + Wneg, pool)


def validate(n_tests=150, seed=7):
    from pysat.solvers import Cadical153
    rng = random.Random(seed)
    for t in range(n_tests):
        n = rng.randint(3, 8) if t < n_tests - 10 else 10
        coeffs = {v: rng.randint(-9, 9) for v in range(1, n + 1)}
        lo = sum(min(0, d) for d in coeffs.values())
        hi = sum(max(0, d) for d in coeffs.values())
        bound = rng.randint(lo - 2, hi + 2)
        pool = Pool(n + 1)
        cls = encode_signed_leq(coeffs, bound, pool)
        with Cadical153(bootstrap_with=cls) as s:
            for asg in range(1 << n):
                assume = [(v if (asg >> (v - 1)) & 1 else -v) for v in range(1, n + 1)]
                tot = sum(d for v, d in coeffs.items() if (asg >> (v - 1)) & 1)
                expect = (tot <= bound)
                got = s.solve(assumptions=assume)
                assert got == expect, (coeffs, bound, asg, tot, expect, got)
    return n_tests


if __name__ == "__main__":
    k = validate()
    print(f"[OK] encoder PB validato per forza bruta su {k} istanze casuali "
          f"(tutti gli assegnamenti, entrambe le direzioni)")
