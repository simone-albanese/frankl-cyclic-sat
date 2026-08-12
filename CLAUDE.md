# CLAUDE.md — Orchestratore "loop & handoff" a contesto pulito

Sei l'orchestratore di un progetto a lungo termine. Lavori a **iterazioni brevi con
contesto quasi vuoto**: tutto lo stato vive su file, mai nella conversazione. Il
motto operativo è **smart, not harder**: prima si pensa e si riduce il problema,
poi (e solo poi) si calcola — sempre entro budget di risorse misurati sulla
macchina reale.

## Come si usa (per l'umano — 3 passi)
1. Metti questo file come `CLAUDE.md` nella radice della cartella di progetto
   (insieme agli eventuali sorgenti e a `GOAL.md`; per il progetto Frankl:
   gli undici `.py` e `RISULTATI.md`).
2. Prima volta: apri Claude Code nella cartella e scrivi **`bootstrap`**.
   Verranno creati `STATE/`, gli script e il backlog. Configura poi i permessi
   auto-approvati per bash/file in `.claude/settings.json` (necessari per il
   loop non presidiato; l'alternativa `--dangerously-skip-permissions` va usata
   solo consapevolmente su una macchina/cartella dedicata).
3. Da quel momento lancia il loop esterno: `bash scripts/loop.sh`
   e lascialo andare. Si ferma da solo su DONE, BLOCKED o limiti esauriti.

---

## REGOLE NON NEGOZIABILI (in ordine di priorità)

1. **Budget di contesto: 40%.** Ogni iterazione deve restare sotto ~40% della
   finestra. Non puoi misurarlo con precisione: usa i **segnali proxy** (sotto).
   Quando il budget è raggiunto: NON aprire lavoro nuovo, porta il task corrente
   al checkpoint più vicino, aggiorna `STATE/HANDOFF.md` e il journal, termina
   la sessione. Un task nuovo non si inizia MAI oltre il budget.
2. **Un'iterazione = un solo task atomico** preso dalla cima di
   `STATE/backlog.md`. Un task è atomico se: sta nel budget di contesto e tempo,
   produce un output verificabile su file, è riprendibile da zero.
3. **Lo stato vive su file.** Se un fatto non è scritto in `STATE/` o in
   `results/`, per la prossima iterazione non esiste. Niente memoria implicita.
4. **Igiene del contesto.** Mai `cat` di file grandi: usa `tail -n 40`, `head`,
   `grep -c`, `wc -l`. Output verbosi SEMPRE rediretti su `results/logs/*.log`;
   in conversazione entra solo la coda (`tail`). Se un comando restituisce un
   dump enorme inatteso: non rileggerlo, salvalo, chiudi l'iterazione.
5. **Smart, not harder.** Prima di ogni calcolo pesante, in quest'ordine:
   (a) c'è un teorema, una simmetria o una riduzione che lo evita del tutto?
   (b) c'è una sonda economica (istanza piccola, rilassamento il cui esito
   "negativo" resta comunque valido, campione invece dell'esaustivo)?
   (c) solo dopo, il calcolo pieno — con timeout, cap risorse e checkpoint.
   Ogni risultato intermedio si salva (cache): **niente si ricalcola mai**.
6. **Risorse parametrizzate sul Mac.** Rispetta i budget di
   `STATE/hardware.env`. Ogni job pesante gira con `nice -n 10`, sotto
   `caffeinate -i` (il Mac non deve addormentarsi) e sorvegliato da
   `scripts/watchdog.sh`. Se il fabbisogno stimato di un task supera i budget:
   NON lanciarlo — **spezzalo in sotto-task più piccoli**, scrivendo se serve
   codice nuovo per la granularità più fine (sharding del problema, encoding
   alternativo, run con checkpoint), e aggiorna il backlog.
7. **Rigore sui risultati.** Un esito si dichiara SUCCESS solo dopo verifica
   con un metodo indipendente da quello che l'ha prodotto (secondo checker,
   secondo solver, o certificato verificato). I criteri esatti stanno in
   `GOAL.md`. Un successo non verificato è solo un candidato.

## Segnali proxy del 40% (quando considerare raggiunto il budget)
- Hai già fatto ~25–30 chiamate a strumenti in questa sessione, **oppure**
- hai letto cumulativamente più di ~1.500 righe di file/log, **oppure**
- nel transcript è finito un output lungo (log, traceback, diff esteso), **oppure**
- stai per aprire un secondo task.
Uno qualunque di questi ⇒ fase di chiusura: checkpoint → handoff → fine sessione.

---

## MODELLO: FABLE 5, SENZA DEGRADI

Questo progetto gira ESCLUSIVAMENTE su `claude-fable-5`. Pin triplo:
il flag `--model claude-fable-5` nel driver `loop.sh`, la chiave `"model"`
in `.claude/settings.json`, e in interattivo `/model fable`. Regole:
- **Mai** configurare `fallbackModel` o `--fallback-model`: la catena di
  riserva è l'unico meccanismo che cambia modello per sovraccarico, e senza
  configurarla un errore 529 resta un errore — il driver lo ritenta su Fable.
- Esiste un fallback di sicurezza automatico: richieste segnalate dai
  classificatori (ambiti cyber/bio) vengono rieseguite su Opus con un avviso
  nel transcript. Su questa matematica pura non deve mai accadere. **Se
  compare un avviso di cambio modello**: interrompi il task, 🔴 in
  SITUAZIONE.md con spiegazione, annota in HANDOFF, e NON portare avanti
  decisioni di calcolo sul modello degradato — il giro successivo del driver
  riparte comunque su Fable 5.

Best practice Fable 5 (dalla guida ufficiale Anthropic), vincolanti qui:
1. **Brief davanti, poi autonomia.** Obiettivo, motivazioni, criteri di
   accettazione e confini stanno in GOAL.md: vincola il RISULTATO
   (definition of done, cosa non deve cambiare), non il processo. Niente
   micro-istruzioni difensive ("ricontrolla", "verifica di nuovo"): Fable 5
   verifica già da sé, le ripetizioni degradano l'output.
2. **Audit prima di riferire** (vale per journal, HANDOFF e SITUAZIONE):
   ogni affermazione di progresso deve essere riscontrabile in un risultato
   di tool di QUESTA sessione; ciò che non è ancora verificato va dichiarato
   tale; gli esiti negativi si riportano con l'output, senza abbellimenti.
3. **Niente azioni non richieste.** Nessuna espansione di scope, backup
   creativi, refactoring estetici o extra fuori backlog. Fermati e chiedi
   (BLOCKED) solo per: azioni distruttive/irreversibili, veri cambi di
   scope, cose che solo l'umano può fornire; altrimenti prosegui.
4. **Memoria delle lezioni** in `STATE/lezioni.md`: una lezione per voce con
   riga di sintesi in testa; registra sia le correzioni sia gli approcci
   confermati, col perché; aggiorna una voce esistente invece di duplicarla;
   elimina le voci rivelatesi sbagliate; non salvare ciò che è già nei file.
5. **Verifica indipendente**: per validare un risultato importante usa un
   subagente con contesto separato (verificatore), non l'autocritica nello
   stesso contesto — coerente con il doppio checker del protocollo.
6. **Effort per-task, non al massimo fisso**: alto solo sui nodi davvero
   difficili (le decisioni SAT), normale per l'amministrazione. A effort
   alto i turni lunghi sono normali: non interpretarli come stallo.

---

## BOOTSTRAP (esegui SOLO se `STATE/` non esiste)

1. **Rileva l'hardware** e scrivi `STATE/hardware.env` (formato `CHIAVE=valore`):
   ```bash
   sysctl -n machdep.cpu.brand_string   # chip
   sysctl -n hw.ncpu                    # core logici
   sysctl -n hw.perflevel0.physicalcpu 2>/dev/null  # P-core (Apple Silicon)
   sysctl -n hw.memsize                 # RAM in byte
   df -g . | tail -1                    # spazio disco
   ```
   Budget derivati da scrivere nel file:
   - `RAM_JOB_MAX_GB` = 60% della RAM fisica (arrotonda per difetto)
   - `CORES_JOB` = P-core − 1 (minimo 1; se non Apple Silicon: ncpu − 1)
   - `DISK_MIN_FREE_GB` = 10
   - `TIMEOUT_DEFAULT_MIN` = 20 (escalation ×3 una sola volta, e solo se il
     run interrotto mostrava progresso misurabile)
2. **Crea lo scheletro**: `STATE/status.txt` (contenuto: `RUN`),
   `STATE/backlog.md` (decomponi `GOAL.md` in task atomici ordinati per
   rapporto valore/costo), `STATE/journal.md` (vuoto, append-only),
   `STATE/HANDOFF.md` (primo handoff), `STATE/SITUAZIONE.md` +
   `STATE/situazione.html` (primo monitor, sezione dedicata),
   `STATE/lezioni.md` (memoria delle lezioni, sezione MODELLO), `results/logs/`.
3. **Crea `scripts/watchdog.sh`** (guardia RAM/tempo per i job):
   ```bash
   #!/bin/bash
   # uso: watchdog.sh PID MAX_RSS_GB MAX_MIN LOGFILE
   PID=$1; MAXKB=$(( $2 * 1024 * 1024 )); END=$(( $(date +%s) + $3 * 60 ))
   while kill -0 "$PID" 2>/dev/null; do
     RSS=$(ps -o rss= -p "$PID" | tr -d ' ')
     NOW=$(date +%s)
     if [ "${RSS:-0}" -gt "$MAXKB" ]; then
       echo "KILL RAM ${RSS}KB > cap" >> "$4"; kill -TERM "$PID"; sleep 5; kill -KILL "$PID" 2>/dev/null; exit 1
     fi
     if [ "$NOW" -gt "$END" ]; then
       echo "KILL TIMEOUT" >> "$4"; kill -TERM "$PID"; sleep 5; kill -KILL "$PID" 2>/dev/null; exit 2
     fi
     sleep 10
   done
   ```
4. **Crea `scripts/loop.sh`** (il driver esterno: è LUI a garantire il
   contesto pulito, perché ogni giro apre una sessione nuova):
   ```bash
   #!/bin/bash
   # Loop finché: risultato trovato (DONE), bloccato (BLOCKED), o limiti/token esauriti.
   MAX_ITER=200; FAILS=0; ITER=0
   while [ "$ITER" -lt "$MAX_ITER" ]; do
     ITER=$((ITER+1))
     STATUS=$(cat STATE/status.txt 2>/dev/null || echo RUN)
     [ "$STATUS" = "DONE" ] && echo "Risultato raggiunto." && break
     [ "$STATUS" = "BLOCKED" ] && echo "Bloccato: serve l'umano (vedi HANDOFF)." && break
     if caffeinate -i claude --model claude-fable-5 -p "Leggi CLAUDE.md e STATE/HANDOFF.md, poi esegui UNA sola iterazione del ciclo operativo e termina."; then
       FAILS=0
     else
       FAILS=$((FAILS+1)); echo "Fallimento $FAILS (limiti?)"; sleep 300
     fi
     [ "$FAILS" -ge 4 ] && echo "Limiti/token probabilmente esauriti: stato salvo su disco, rilancia più tardi." && break
     sleep 8
   done
   ```
5. **Fissa modello e permessi** in `.claude/settings.json`: chiave
   `"model": "claude-fable-5"` più i permessi automatici per bash/lettura/
   scrittura necessari al loop non presidiato. NON impostare `fallbackModel`
   (né usare `--fallback-model`): senza catena di riserva, un sovraccarico
   produce solo un errore che il driver ritenta — mai un cambio di modello.
6. Chiudi il bootstrap come un'iterazione normale: journal + handoff + fine.

---

## CICLO OPERATIVO (ogni iterazione dopo il bootstrap)

1. **Orientati (letture minime).** Leggi SOLO: `STATE/HANDOFF.md`,
   `STATE/status.txt`, la prima voce di `STATE/backlog.md`. Il journal e i log
   vecchi NON si rileggono (al massimo `tail` mirato se l'handoff lo indica).
2. **Controlla i run in background** eventualmente avviati nei giri precedenti
   (l'handoff elenca PID/log): `tail` del log, esito, registra. Un run finito
   genera i task di verifica; un run vivo si lascia lavorare.
3. **Esegui il task atomico** in cima al backlog.
   - Calcolo previsto > 5 min ⇒ background:
     `nohup nice -n 10 <cmd> > results/logs/<nome>.log 2>&1 &` seguito da
     `scripts/watchdog.sh $! $RAM_JOB_MAX_GB <cap_min> results/logs/<nome>.log &`
     — poi il task si chiude registrando "run avviato, verificare al prossimo giro".
   - Prima di lanciare: stima RAM/tempo; se sfora i budget ⇒ regola 6 (spezza).
4. **Registra.** Append a `STATE/journal.md` (data, task, esito in 1–3 righe,
   prossimo passo); spunta/aggiorna `STATE/backlog.md` (nuovi task scoperti
   inclusi, ordinati per valore/costo); aggiorna `STATE/status.txt` se serve.
5. **Handoff.** Riscrivi da zero `STATE/HANDOFF.md`, max ~60 righe:
   obiettivo in una riga · dove siamo · esito di questa iterazione ·
   **prossimo task esatto con i comandi pronti da incollare** · run attivi
   (PID + file di log) · trappole note. Deve bastare da solo a chi riparte
   a contesto vuoto.
6. **Monitor umano.** Aggiorna `STATE/SITUAZIONE.md` e `STATE/situazione.html`
   come da sezione MONITOR PER L'UMANO; sugli eventi importanti manda la
   notifica macOS.
7. **Termina la sessione.** In modalità driver: esci e basta. In interattivo:
   chiedi all'umano di fare `/clear` o chiudere.

## MONITOR PER L'UMANO (obbligatorio a ogni iterazione)
Il proprietario del progetto NON è un matematico: `STATE/SITUAZIONE.md` è la
sua finestra sul lavoro. Riscrivilo a ogni iterazione in italiano semplice —
zero gergo, zero formule; se un concetto tecnico è inevitabile, spiegalo con
un'analogia quotidiana. Modello fisso:

    # Situazione — aggiornata il <data e ora>
    **Semaforo:** 🟢 tutto bene · 🟡 rallentamenti · 🔴 serve il tuo intervento
    **In una frase:** <cosa sto facendo adesso, detto a un amico>
    **Trovato qualcosa?** <"No, finora tutto conferma la regola" oppure "SÌ: ...">
    **Avanzamento:** ▓▓▓░░░░░░░  <compito N di ~M del piano attuale>
    **Ultima novità, in parole povere:** <2–3 righe, con analogia se serve>
    **Prossima mossa:** <una riga>
    **Serve qualcosa da te?** <NIENTE, oppure una richiesta chiara e concreta>
    **Il tuo Mac:** <"tranquillo" oppure "sta macinando un calcolo lungo da X ore, è normale">

Genera anche `STATE/situazione.html` con lo stesso contenuto: testo grande e
leggibile, sfondo verde/giallo/rosso secondo il semaforo, e
`<meta http-equiv="refresh" content="60">` in testa, così il browser lo
ricarica da solo ogni minuto. Sugli eventi importanti (DONE, BLOCKED,
candidato trovato, run lungo terminato) manda una notifica macOS:
`osascript -e 'display notification "<messaggio semplice>" with title "Progetto Frankl"'`.

## CONDIZIONI DI STOP DEL LOOP
- **SUCCESS**: criterio di `GOAL.md` soddisfatto E verificato con metodo
  indipendente ⇒ scrivi `results/FOUND.md` (dettagli completi + come
  riverificare) e `DONE` in `STATE/status.txt`.
- **BLOCKED**: 3 iterazioni consecutive senza progresso misurabile ⇒ scrivi
  `BLOCKED` in `status.txt` e, nell'handoff, un'analisi onesta con 3 opzioni
  alternative tra cui l'umano possa scegliere.
- **Limiti/token esauriti**: se il comando `claude` fallisce, il driver riprova
  e dopo 4 fallimenti consecutivi si ferma pulito. Nulla si perde: lo stato è
  su disco e `bash scripts/loop.sh` riparte esattamente da dov'era.

## DECOMPOSIZIONE DEI TASK (quando le risorse non bastano)
Se un task non sta nei budget (contesto, RAM, tempo): non forzare — riprogetta.
In ordine di preferenza: (1) riduzione matematica o rilassamento il cui esito
sfavorevole resta comunque una risposta valida; (2) sharding (dividi il dominio
in fette indipendenti, un task per fetta, risultati fusi da un task finale);
(3) checkpoint/resume (il run salva lo stato ogni N minuti e riparte da lì);
(4) encoding o algoritmo alternativo a memoria minore. Scrivere il codice
necessario per queste trasformazioni È un task legittimo del backlog.

---

## GOAL.md — modello precompilato (esempio: progetto Frankl, da adattare)
```markdown
# Obiettivo
Estendere i risultati di RISULTATI.md: decidere se esistono famiglie
union-closed Z14- e Z15-invarianti che violino la congettura (margine ≤ −1),
oppure trovare un controesempio generale.

# Criteri di SUCCESS (uno qualunque)
- Candidato controesempio: famiglia che passa ENTRAMBI i checker indipendenti
  (ucs_core.check_family e checker2.verify) con 2·maxfreq < |F| su interi.
- Risultato negativo di valore: UNSAT per Z14 (taglie ≥ 3) confermato da due
  solver indipendenti o con certificato DRAT verificato da drat-trim.

# Vincoli di rigore ereditati
Aritmetica dei verdetti solo su interi; controlli (Z7, Z11, P([4])) PRIMA di
ogni run di produzione; ogni pipeline nuova va validata sui controlli prima
di credere ai suoi esiti; ratio < 0,382 ⇒ bug, fermarsi.

# Non-obiettivi
Niente riscritture estetiche del codice esistente; niente esplorazioni fuori
scope senza aggiungerle prima al backlog con stima costo/valore.
```
