# The Mathematics

*Formal companion to the [README](../README.md). Everything here is elementary —
undergraduate combinatorics and a little group theory — but stated precisely,
because the value of a computer-assisted result lives or dies on the precision
of what was actually decided.*

---

## 1. The conjecture

Let $F$ be a finite family of finite sets. $F$ is **union-closed** if
$A, B \in F \implies A \cup B \in F$. For an element $x$, its **frequency** is
$\mathrm{freq}_F(x) = |\{S \in F : x \in S\}|$.

> **Conjecture (Frankl, c. 1979).** Every union-closed family $F$ containing at
> least one nonempty set has an element $x$ with
> $2\cdot\mathrm{freq}_F(x) \ge |F|$.

An element with $2\,\mathrm{freq}(x) \ge |F|$ is called **abundant**. A
**counterexample** is a union-closed family (with a nonempty member) in which
every element $x$ satisfies the strict integer inequality
$2\,\mathrm{freq}(x) < |F|$, equivalently

$$\text{margin}(F) \;:=\; 2\max_x \mathrm{freq}_F(x) \;-\; |F| \;\le\; -1 .$$

Throughout this project all verdicts are computed on integers with this margin;
no floating-point ratio is ever compared.

## 2. Rotation-invariant families

Fix $m$ and identify the universe with $\mathbb{Z}_m = \{0, 1, \dots, m-1\}$.
The **rotation** is the map $\rho(i) = i + 1 \bmod m$, extended to sets
elementwise. A family $F$ of subsets of $\mathbb{Z}_m$ is **rotation-invariant**
(or $\mathbb{Z}_m$-invariant) if $S \in F \implies \rho(S) \in F$.

**Lemma 1 (uniform frequency).** In a rotation-invariant family every element
has the same frequency $f$, and $f \cdot m = \sum_{S \in F} |S|$.

*Proof.* $\rho$ permutes $F$ (it is injective on sets and maps members to
members), and $x \in S \iff x+1 \in \rho(S)$; summing over $F$ gives
$\mathrm{freq}(x) = \mathrm{freq}(x+1)$ for all $x$, so all frequencies equal
some $f$. Counting the pairs $\{(x, S) : x \in S \in F\}$ by columns gives
$f\cdot m$ and by rows gives $\sum_{S} |S|$. ∎

**Corollary (the margin identity).** For rotation-invariant $F$,

$$\mathrm{margin}(F) \;=\; 2f - |F| \;=\; \frac{1}{m}\sum_{S \in F} \bigl(2|S| - m\bigr),$$

so $F$ satisfies the conjecture **iff** the total "size excess"
$\sum_{S\in F}(2|S| - m)$ is $\ge 0$. A counterexample is a union-closed
invariant family dominated by sets smaller than $m/2$.

## 3. Reductions (all standard, all used)

**(R1) The empty set may be assumed present.** Adding $\varnothing$ preserves
union-closure and invariance, adds $1$ to $|F|$ and $0$ to every frequency —
it can only make the margin *smaller*. So if any counterexample exists, one
with $\varnothing \in F$ exists.

**(R2) The full set is automatically present.** The union of *all* members of a
finite union-closed family is itself a member (fold the pairwise unions). For
an invariant family with a nonempty member, that top set is a nonempty
rotation-invariant subset of $\mathbb{Z}_m$, hence $\mathbb{Z}_m$ itself.

Together, (R1)+(R2) let us normalize every candidate family to contain both
$\varnothing$ and $\mathbb{Z}_m$. Their joint contribution to the margin is
$2\cdot 1 - 2 = 0$: they cancel, which is why the models below can simply
hard-include them.

**(R3) No member sets of size 1 or 2.** If $\{x\} \in F$, then $x$ is abundant:
$A \mapsto A \cup \{x\}$ maps the members not containing $x$ injectively into
the members containing $x$. If some $\{x,y\} \in F$, then $x$ or $y$ is
abundant (Sarvate–Renaud). Hence **a counterexample contains no set of size 1
or 2**, and searches may be restricted to families whose nontrivial members
have size ≥ 3. (The analogous statement for 3-sets is false, so this is where
the free reductions stop.)

Usage in this project: the $\mathbb{Z}_{13}$ decision ran **without** (R3) —
the stronger, unrestricted statement — while $\mathbb{Z}_{14}$ and
$\mathbb{Z}_{15}$ used (R3), which is lossless for counterexample hunting and
shrinks the instances.

## 4. Orbits, periods, and the finite model

A rotation-invariant family is a disjoint union of **orbits**
$O(S) = \{\rho^k(S) : k\}$. All sets in an orbit share one size $s_O$, and the
orbit has a **period** $r_O = |O|$, which divides $m$.

**Lemma 2 (period structure and integrality).** If $|O| = r$, then each member
of $O$ is invariant under rotation by $r$, hence is a union of residue classes
modulo $r$ (each class has $m/r$ elements). Writing $k$ for the number of
classes used, $s_O = k\,m/r$, so $r\,s_O = k\,m$ and the quantity

$$d_O \;:=\; \frac{r_O\,(2 s_O - m)}{m} \;=\; 2k - r \;\in\; \mathbb{Z}.$$

*Proof.* The stabilizer of $S$ in $\mathbb{Z}_m$ is a subgroup, i.e.
$\langle r\rangle$ with $r = m/|\mathrm{stab}|$ equal to the orbit size
(orbit–stabilizer); a set stabilized by $\langle r \rangle$ is a union of its
point-orbits, which are exactly the residue classes mod $r$. ∎

Choosing a rotation-invariant family (normalized per (R1)–(R2)) is exactly
choosing a set of nontrivial orbits. With a Boolean variable $x_O$ per orbit:

$$|F| = 2 + \sum_O r_O\, x_O, \qquad
f = 1 + \frac{1}{m}\sum_O r_O\, s_O\, x_O, \qquad
\mathrm{margin} = \sum_O d_O\, x_O .$$

**The decision problem.** Does there exist an assignment with

1. **Union-closure:** for every pair of chosen orbits, every union of two of
   their members lies in a chosen orbit (or is $\mathbb{Z}_m$);
2. **Margin:** $\sum_O d_O x_O \le -1$ — equivalently, in the scaled integer
   form used by the CP-SAT model, $\sum_O r_O(2s_O - m)\,x_O \le -m$;
3. **Nontriviality:** at least one orbit chosen?

If **UNSAT/infeasible**: no rotation-invariant counterexample on $m$ points.
If **SAT**: the assignment is a candidate counterexample (to be verified by two
independent checkers on the explicit family).

**Closure clauses, and why one representative suffices.** For orbits $O_1, O_2$
with canonical representatives, it is enough to fix $A = \mathrm{rep}(O_1)$ and
let $B$ range over all of $O_2$, emitting
$\lnot x_{O_1} \lor \lnot x_{O_2} \lor x_{O(A\cup B)}$ whenever $A \cup B$ is
not $\mathbb{Z}_m$ and not already in $O_1 \cup O_2$: any other pair
$(A', B')$ is a rotation of such a pair, and the clause set is
rotation-closed by construction. Note $O_1 = O_2$ is *not* skipped — the union
of two rotations of the same set can land in a third orbit. This cuts the naive
$O(r_1 r_2)$ pair enumeration to $O(r_2)$ per orbit pair and is implemented
identically in both encoders ([sat_cyclic.py](../sat_cyclic.py),
[dump_dimacs.py](../dump_dimacs.py)).

**The margin constraint in CNF.** The DIMACS pipeline encodes
$\sum d_O x_O \le -1$ through a binary-adder (ripple-carry) pseudo-Boolean
circuit ([pb_adder.py](../pb_adder.py)) that was validated by brute force
against explicit enumeration on small instances before first use. The CP-SAT
model instead uses the solver's native integer linear constraint. The two
margin formalizations are independent implementations of the same inequality.

## 5. How many orbits? (Burnside)

The number of rotation orbits of subsets of $\mathbb{Z}_m$ is
$N(m) = \frac{1}{m}\sum_{d \mid m}\varphi(d)\,2^{m/d}$; subtracting the two
trivial orbits $\{\varnothing\}$ and $\{\mathbb{Z}_m\}$ gives the variable
counts:

| $m$ | 7 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|---|---|---|---|---|---|---|---|---|
| nontrivial orbits | 18 | 186 | 350 | 630 | 1,180 | 2,190 | 4,114 | 7,710 |

For prime $m$ this is just $(2^m-2)/m$ (all nontrivial orbits have full period
$m$). For composite $m$ the period spectrum matters; e.g. for $m = 15$ the
probe measured periods $\{3: 2,\ 5: 6,\ 15: 2182\}$, which checks out exactly:
period-3 orbits come from unions of the three residue classes mod 3
($2^3 - 2 = 6$ sets in $2$ orbits), period-5 from classes mod 5
($2^5 - 2 = 30$ sets in $6$ orbits), and
$2182 \cdot 15 + 6\cdot 5 + 2\cdot 3 = 32{,}766 = 2^{15} - 2$. ∎

## 6. The Cauchy corollary (why 13 is special)

**Proposition.** If no rotation-invariant union-closed family on 13 points
violates the conjecture, then no union-closed family invariant under *any*
transitive permutation group $G \le \mathrm{Sym}(13)$ violates it.

*Proof.* Transitivity gives $13 \mid |G|$ (orbit–stabilizer). By Cauchy's
theorem $G$ contains an element $g$ of order 13; in $\mathrm{Sym}(13)$ every
element of order 13 is a 13-cycle. Relabel the points so that
$g = (0\,1\,\cdots\,12)$. A $G$-invariant family is in particular
$\langle g\rangle$-invariant, i.e. rotation-invariant. ∎

This is why the $\mathbb{Z}_{13}$ result closes the *entire* transitive story
on 13 points. The argument is specific to primes: on 14, 15 or 16 points there
are transitive groups containing no long cycle — for instance
$\mathrm{PSL}(2,13)$ acting on the 14 points of the projective line has element
orders $\{1,2,3,6,7,13\}$, so no 14-cycle. Classifying which transitive groups
on 14–16 points escape the cyclic case, and deciding those, is
[open problem 4](open-problems.md#problem-4--transitive-groups-without-long-cycles).

## 7. The quantitative $\mathbb{Z}_{13}$ result

Beyond yes/no, the CP-SAT model was run in optimization mode over
rotation-invariant closed families on 13 points with member sizes ≥ 3
(nontrivial, normalized): the minimum of the margin is

$$\min \mathrm{margin} = 11 \;>\; 0 \quad (\text{scaled: } \min m\!\cdot\!M = 143 = 13 \cdot 11,\ \text{status OPTIMAL}),$$

attained by the 15-set family
$F^\* = \{\varnothing,\ \mathbb{Z}_{13}\} \cup O(\text{a 12-element set})$:
thirteen 12-sets, each element missing from exactly one of them, so
$f = 12 + 1 = 13$, $|F^\*| = 15$, margin $= 26 - 15 = 11$, frequency ratio
$13/15 \approx 0.867$. An independent enumeration (cyclic closures of single
seeds, [cyclic_enum.py](../cyclic_enum.py)) reproduces the same scaled margin
143 for the same family. In words: **on 13 points, even the tightest symmetric
family clears the conjecture's bar by a comfortable, certified distance** — the
landscape near a would-be counterexample is not even close.

The same enumeration swept all 630 single-seed cyclic closures on
$\mathbb{Z}_{13}$ (and the analogous sweeps on 14, partial on 15): margins are
never negative, consistent with — and experimentally extending — the theorem of
Aaronson–Ellis–Leader for single-orbit generated families.

## 8. What is decided, and what is not

- Decided (and certified): *the rotation-invariant case* on 13 and 14 points,
  and by §6 the full transitive case on 13 points.
- Decided by a single method (unconfirmed): the rotation-invariant case on 15
  points. See [results/Z15-PARTIAL.md](../results/Z15-PARTIAL.md).
- **Not** decided by any of this: Frankl's conjecture for general
  (asymmetric) families on ≥ 13 points. A general counterexample, if one
  exists, simply need not be symmetric. The contribution of symmetry results is
  to close the most structured hunting ground — the one where "every element
  rare" comes for free — and, on primes, the whole transitive regime.
- The results are computational; their trustworthiness rests on the
  certificate-and-controls architecture audited in
  [results.md § trust](results.md#what-you-must-trust).

## References

See the [README's reference list](../README.md#references). Statements (R3),
the ≤ 12-point verification, the $4m-1$ bound and the 0.382 bounds are cited
there; Lemmas 1–2 and the propositions above are elementary and proved here.
