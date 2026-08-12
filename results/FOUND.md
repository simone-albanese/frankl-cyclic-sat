# FOUND — Risultato negativo di valore su Z14 (criterio (b) di GOAL.md)

**Data:** 2026-08-11 16:48
**Esito:** Non esistono famiglie union-closed **Z14-invarianti** (generatori di
taglia ≥ 3) con margine intero `2*maxfreq - |F| <= -1`. La congettura di Frankl
è confermata su tutta la classe Z14.

## Perché il criterio (b) è soddisfatto
GOAL.md richiede: "UNSAT per Z14 (taglie ≥ 3) confermato da due solver
indipendenti **o** con certificato DRAT verificato da drat-trim". Qui valgono
**entrambe** le condizioni:

1. **CP-SAT (OR-Tools)** — T4: esito `{"status": "INFEASIBLE", "m": 14}`.
   Log: `results/logs/T4_z14_cpsat_min3.log`.
2. **CaDiCaL** — T6: encoding CNF indipendente (`results/z14min3.cnf`,
   7.342.059 clausole), esito `s UNSATISFIABLE` (exit 20).
   Log: `results/logs/T6_cadical_z14.log`.
3. **Certificato DRAT verificato** — T6 chiusura: `drat-trim` su
   `results/z14min3.drat` (2,2 GB) ha risposto **`s VERIFIED`**
   (backward checking, 1736.034 s; 3.411.578 lemmi in core,
   0 lemmi RAT problematici). Log: `results/logs/T6_drat_z14.log`.
   I warning "duplicate literal" in parsing sono benigni (letterali duplicati
   deduplicati, non errori).

## Come riverificare da zero
```bash
# 1. Integrità degli artefatti (hash in results/FOUND.sha256):
shasum -a 256 -c results/FOUND.sha256

# 2. Rigenerare esito CaDiCaL + certificato (ore di calcolo):
tools/cadical/build/cadical results/z14min3.cnf results/z14min3.drat
#    atteso: "s UNSATISFIABLE" (exit code 20)

# 3. Verificare il certificato (~30 min, ~2 GB RAM):
tools/drat-trim/drat-trim results/z14min3.cnf results/z14min3.drat
#    atteso: "s VERIFIED"

# 4. (Indipendente) CP-SAT sharded: comandi di T4 nel backlog,
#    .venv/bin/python3 — mai python3 nudo.
```

## Artefatti (NON cancellare: sono la prova)
- `results/z14min3.cnf` — 117 MB — sha256 `f9283cb3…59bab4`
- `results/z14min3.drat` — 2,2 GB — sha256 `33494a39…738a87`
- `results/FOUND.sha256` — hash completi
- Log: `results/logs/T6_drat_z14.log`, `T6_cadical_z14.log`, `T4_z14_cpsat_min3.log`

## Contesto e seguito
- Z13 era già deciso (UNSAT + DRAT verificato, vedi RISULTATI.md). Questo
  risultato estende la conferma a Z14, il primo caso multi-orbita aperto.
- **Z15 è il seguito naturale** (task T7+ del backlog, già impostati).
  GOAL.md dichiara SUCCESS con "uno qualunque" dei criteri, quindi lo stato
  è DONE: la decisione se proseguire su Z15 spetta all'umano.

## Erratum (2026-08-12)
Il conteggio di clausole originariamente riportato al punto 2 (6.237.856) era
un errore di trascrizione: il valore corretto è **7.342.059**, come da header
DIMACS (`p cnf 5184 7342059`), da `results/logs/T6_dump.log` e dal parsing di
drat-trim ("864118 of 7342059 clauses in core"). Corretto sopra; gli hash in
`results/FOUND.sha256` riguardano i file `.cnf`/`.drat` e restano invariati
(riverificati OK il 2026-08-12).
