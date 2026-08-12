# HANDOFF — 2026-08-12 10:00 (chiusura definitiva) · STATUS: DONE

**Il progetto in questa forma è CHIUSO su decisione esplicita del proprietario
(12/08 ore 09:58). NON rilanciare `scripts/loop.sh`.**

**Obiettivo (com'era):** decidere se esistono famiglie union-closed Z14/Z15-invarianti
con margine intero `2*maxfreq - |F| <= -1`, o un controesempio generale a Frankl.

**Esito finale:**
- **Z13** — UNSAT, certificato DRAT verificato (storico, `RISULTATI.md`).
- **Z14** — UNSAT, doppio solver indipendente + certificato DRAT verificato
  (`results/FOUND.md`, hash riverificati il 12/08: OK). Criterio (b) di GOAL.md
  soddisfatto ⇒ DONE.
- **Z15** — CP-SAT dice INFEASIBLE (T9a, ~15 min); la conferma indipendente
  (CaDiCaL, T9b) è stata fermata dopo ~12h56m senza verdetto. Il DRAT parziale
  (11,87 GiB) NON è un certificato. Dettagli: `results/Z15-PARTIAL.md`.
  **Z15 resta non confermato** secondo lo standard del progetto.

**Cosa è successo il 12/08 mattina:** analisi di fattibilità in sola lettura
(P(verdetto in tempo) ~10–15%; drat-trim su prova ~14 GiB stimato 11–18 GB RAM,
oltre i 16 GB fisici) ⇒ il proprietario ha deciso: stop e pubblicazione.
SIGTERM puliti a loop.sh (PID 28034), watchdog (91586) e CaDiCaL (3984, ore
09:58:46; statistiche finali in coda a `results/logs/T9b_cadical_z15.log`).

**Stato attuale:** repository preparato per la pubblicazione su GitHub con
documentazione completa in inglese: `README.md` + `docs/` (mathematics, results,
reproducing, getting-started, open-problems, ai-workflow). I file originali
italiani (RISULTATI.md, STATE/, results/FOUND.md) restano come fonte storica
primaria.

**Trappole per chi riprende:**
- I `.cnf`/`.drat` grandi sono esclusi da git (`.gitignore`): si rigenerano con
  la pipeline (`docs/reproducing.md`); gli hash sha256 sono nei docs e in
  `results/FOUND.sha256`.
- Il DRAT parziale Z15 non va usato come certificato; conservato fuori da git.
- `python3` nudo resta l'interprete sbagliato: usare `.venv/bin/python3`.
- Chi vuole proseguire (conferma Z15 via sharding, Z16, gruppi transitivi):
  partire da `docs/open-problems.md`.
