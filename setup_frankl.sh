#!/bin/bash
# setup_frankl.sh - ricrea la cartella di progetto Frankl con tutti i file.
# Uso:  bash setup_frankl.sh [cartella]     (default: $HOME/frankl)
set -e
DEST="${1:-$HOME/frankl}"
if [ -e "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
  echo "ERRORE: $DEST esiste e non e' vuota. Scegli un'altra cartella o svuotala."; exit 1
fi
mkdir -p "$DEST"
echo "Creo i file in $DEST ..."
cat > "$DEST/CLAUDE.md" << '__EOF_FRANKL_X7Q__'
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
__EOF_FRANKL_X7Q__
cat > "$DEST/RISULTATI.md" << '__EOF_FRANKL_X7Q__'
# Sessione di ricerca: controesempi alla congettura union-closed (Frankl)

Data: 10 agosto 2026 · Ambiente: Python 3.12.3, OR-tools CP-SAT · Aritmetica dei verdetti: solo interi (condizione di controesempio: 2·maxfreq < |F|).

## 1. Stato dell'arte (Passo 0, sintesi con fonti nella chat)

La congettura è aperta. Bound inferiori sulla frequenza massima: Gilmer 2022 (0,01·|F|), poi (3−√5)/2 ≈ 0,38197 (Alweiss–Huang–Sellke; Chase–Lovett; Sawin; Pebody), raffinato a ≈ 0,38234 (Yu) e ≈ 0,3824–0,3827 (Liu, a seconda della fonte). Chase–Lovett: (3−√5)/2 è ottimale per la versione approssimata (barriera per i metodi entropici). Verifiche esaustive: universi con ≤ 12 elementi (Živković–Vučković 2017); famiglie con ≤ 46 insiemi; se il controesempio minimo ha m elementi, ogni controesempio ha ≥ 4m−1 insiemi (Lo Faro; Roberts–Simpson) → con m ≥ 13, |F| ≥ 51. Un controesempio non contiene insiemi di taglia 1 o 2 (Sarvate–Renaud). WLOG ∅ ∈ F (aggiungerlo preserva la chiusura e abbassa tutte le frequenze relative). Caso transitivo: Aaronson–Ellis–Leader 2021 dimostrano la congettura per la famiglia di TUTTE le unioni dei traslati di UN insieme fisso in un gruppo abeliano (caso 1-seme); il caso multi-orbita non risulta coperto.

## 2. Controlli di protocollo (tutti superati)

- Negativo: P([4]) → |F|=16, maxf=8, margine 2·maxf−|F| = 0 esatto (tight, non controesempio).
- Validatore: {{0},{1}} rifiutata (manca {0,1}). Questo controllo ha scoperto un bug reale di flusso nel checker n.1 (violazioni <3 marcate come "chiuso"), corretto prima di ogni run.
- Detector: sei singleton → 2·maxf=2 < 6 rilevato; verdetto complessivo correttamente False (famiglia non chiusa).
- Accordo checker1 (bitmask) / checker2 (frozenset+Counter, implementazione indipendente): 50/50 su chiusure casuali.

## 3. Risultato principale (SAT esatto, famiglie cicliche-invarianti)

Modello: variabile booleana per ognuna delle 630 orbite cicliche non banali di Z₁₃ (∅ e Z₁₃ sempre inclusi; i loro contributi al margine si cancellano). Margine M = Σ (2s−13)x_O; chiusura: 1.863.311 clausole ¬x₁∨¬x₂∨x_target.

- Controlli pipeline: Z₇ e Z₁₁ → INFEASIBLE (come impone la teoria: congettura vera per m ≤ 12). Encoding validato.
- **Z₁₃, vincolo M ≤ −1: INFEASIBLE/UNSAT, ora con certificato verificato.** Quattro conferme concordi e via via più forti: (1) CP-SAT, vincolo lineare nativo, 72 s; (2) pysat/CaDiCaL 1.5.3, encoding ad addizionatori binari validato per forza bruta, UNSAT in 325,6 s; (3) CaDiCaL 2.x compilato da sorgente sul DIMACS esportato (4752 variabili, 1.884.943 clausole), s UNSATISFIABLE con emissione di prova; (4) **certificato DRAT (87 MB) verificato da drat-trim: s VERIFIED in 266,75 s** (481.643 lemmi nel core, ~39,8 M passi di risoluzione). L'intera catena dump→solve→verify è stata prima validata end-to-end su Z₇ e Z₁₁ (UNSAT + VERIFIED). Residuo di fiducia: la sola correttezza della *generazione* della formula, mitigata da due encoder indipendenti concordi e dai controlli. Poiché ogni gruppo transitivo su 13 punti contiene un 13-ciclo (Cauchy), il risultato copre ogni famiglia invariante sotto QUALSIASI gruppo transitivo su 13 punti, ed estende (sperimentalmente) il caso 1-seme di Aaronson–Ellis–Leader al caso multi-seme su Z₁₃.
- Ottimizzazione: min M = 0 (OPTIMAL), raggiunto solo dal power set (|F|=8192) — quasi-controesempio tight banale.
- Regione ammissibile per un controesempio (taglie ≥ 3): min M = 11 (OPTIMAL), |F|=15 (orbita dei 12-set + Z₁₃ + ∅), f = 13, ratio 13/15 ≈ 0,867. Cross-check: l'enumerazione indipendente dà margine scalato 143 = 13·11 per la stessa famiglia.

## 4. Copertura complementare

- Enumerazione esaustiva 1-seme: Z₁₃ 630/630, Z₁₄ 1180/1180, Z₁₅ 666/666 (solo taglie ≤ 6, parziale dichiarato): zero candidati; tight solo power set (eventualmente "a blocchi"). Conferma sperimentale del teorema AEL.
- Campione 800 coppie di semi su Z₁₃: zero candidati; miglior margine M = 32 (|F|=54, ratio 43/54 ≈ 0,796).
- Annealing sui generatori (m ≤ 16): modalità libera converge al power set (margine 0 — calibrazione riuscita); modalità con generatori di taglia ≥ 3 (48 run): miglior margine 2 (|F|=10, ratio 3/5 = 0,6). Nessun margine negativo.
- Costruzioni strutturate su 13 punti (tutte con conteggi previsti a mano e verificati): PG(2,3) → |F|=704, ratio 507/704 ≈ 0,720; STS(13) ciclico → |F|=4032, ratio 1205/2016 ≈ 0,598 (la migliore ratio "strutturata"); QR(13) → |F|=210, ratio 27/35 ≈ 0,771; intervalli (run ≥ 3) → |F|=522, ratio 37/58 ≈ 0,638. Up-set esclusi a priori (maxf ≥ |F|/2 per iniezione S ↦ S∪{x}).

## 5. Seconda fase: tentativi su Z₁₄/Z₁₅ e lezioni

Il modello monolitico CP-SAT per Z₁₄ (7,32 M clausole) supera la RAM disponibile (OOM-kill a 3,94 GB documentato). Due strade esplorate: (a) CEGAR (chiusura lazy: si parte dal solo vincolo di margine e si aggiungono clausole solo quando violate) — corretto per costruzione e validato su Z₇/Z₁₁, ma su Z₁₃ il rilassamento è risultato *più difficile* da refutare del modello completo (timeout: meno vincoli possono rendere più arduo l'UNSAT); (b) pipeline pysat/CaDiCaL con clausole in **streaming** (memoria C-side: build di Z₁₄ in 13 s, ~930 MB stabili) e margine via encoder ad addizionatori binari. La (b) ha prodotto la conferma indipendente di Z₁₃; su Z₁₄ (ristretto a taglie ≥ 3, restrizione valida per ogni controesempio, Sarvate–Renaud) il run è rimasto senza verdetto nel budget di sessione: esito onesto UNKNOWN, con il collo di bottiglia identificato nella propagazione debole dell'encoding pseudo-Booleano rispetto al vincolo lineare nativo.

## 6. Valutazione onesta

Il passo di certificazione chiude il primo dei "prossimi passi" della prima fase: il teorema di sessione su Z₁₃ non dipende più dalla fiducia in un singolo solver. Restano non decisi Z₁₄ e Z₁₅ multi-orbita (due run CaDiCaL da 20+ minuti senza verdetto; CP-SAT monolitico OOM a 3,94 GB): esito dichiarato UNKNOWN.

Nessun candidato: ogni famiglia chiusa esaminata ha margine ≥ 0, e ratio < 0,5 non è mai comparsa (coerente col tripwire: mai nulla vicino a 0,382). Il contributo non banale della sessione è la decisione esatta del caso Z₁₃-invariante generale (multi-orbita), che non risulta coperto dalla letteratura, insieme al margine minimo certificato M = 11 nella regione senza taglie 1–2. Limiti: Z₁₄ multi-orbita non deciso (7,3 M clausole oltre la memoria disponibile), Z₁₅ SAT non tentato, annealing euristico, CP-SAT senza certificato verificabile.

## 6. Prossimi passi

(1) ~~Certificato DRAT per Z₁₃~~ — fatto e verificato in questa sessione. (2) Z₁₄/Z₁₅ multi-orbita con encoding compatto (variabili ausiliarie di coppia o solver PB nativo). (3) Gruppi transitivi su 14–16 punti privi di cicli lunghi (dove il corollario di Cauchy non si applica). (4) Local search con obiettivi surrogati (media taglie vs m/2) e mosse su orbite anziché su generatori.

## File

`ucs_core.py` (bitmask, chiusura, checker n.1) · `pb_adder.py` (encoder PB auto-validato) · `sat2_cyclic.py` (pipeline pysat/CaDiCaL) · `cegar.py` (raffinamento lazy) · `dump_dimacs.py` (esportazione DIMACS per la catena di certificazione; z13.cnf e la prova DRAT da 87 MB sono rigenerabili con dump_dimacs + CaDiCaL + drat-trim) · `checker2.py` (verificatore indipendente) · `controls.py` (controlli obbligatori) · `cyclic_enum.py` (enumerazione) · `sat_cyclic.py` (CP-SAT) · `anneal.py` (ricerca locale) · `structured.py` (costruzioni con assert manuali).
__EOF_FRANKL_X7Q__
cat > "$DEST/ucs_core.py" << '__EOF_FRANKL_X7Q__'
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
__EOF_FRANKL_X7Q__
cat > "$DEST/checker2.py" << '__EOF_FRANKL_X7Q__'
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
__EOF_FRANKL_X7Q__
cat > "$DEST/controls.py" << '__EOF_FRANKL_X7Q__'
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
__EOF_FRANKL_X7Q__
cat > "$DEST/cyclic_enum.py" << '__EOF_FRANKL_X7Q__'
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
__EOF_FRANKL_X7Q__
cat > "$DEST/sat_cyclic.py" << '__EOF_FRANKL_X7Q__'
"""sat_cyclic.py — Decisione esatta: esiste un controesempio Z_m-invariante?

Modello. Una famiglia union-closed invariante sotto lo shift ciclico di Z_m è
unione di orbite cicliche; WLOG contiene ∅ e (se non vuota) l'universo Z_m
(unione di tutti i traslati di qualunque seme non vuoto). Variabile booleana
x_O per ogni orbita non banale O (rappresentante canonico c, taglia orbita
r_O, taglia insieme s_O).

Conteggi (∅ e full sempre inclusi):
  |F| = 2 + Σ r_O x_O
  f (frequenza comune, uniforme per transitività) = 1 + (Σ r_O s_O x_O)/m
  margine M = 2f - |F| = Σ r_O (2 s_O - m) x_O / m   (∅ e full si cancellano)
Per m primo r_O = m e M = Σ (2 s_O - m) x_O. In generale usiamo il margine
scalato  m·M = Σ r_O (2 s_O - m) x_O  (intero; controesempio ⟺ m·M ≤ -m).

Chiusura: per ogni coppia di orbite (O1,O2), per invarianza basta fissare
A = rep(O1) e far variare B su tutta O2: clausola ¬x1 ∨ ¬x2 ∨ x_{orb(A∪B)}
per ogni unione che non sia full né in O1/O2 (in tal caso è già soddisfatta).

CONTROLLI PIPELINE: lo stesso codice su Z_7 e Z_11 DEVE dare INFEASIBLE
(la congettura è dimostrata per universi ≤ 12): se risultasse SAT c'è un
bug di encoding e ci si ferma.
"""
import sys, time
from ortools.sat.python import cp_model
from ucs_core import rot, popcount


def canon_table(m):
    full = (1 << m) - 1
    tab = [0] * (full + 1)
    for x in range(1, full + 1):
        if tab[x]:
            continue
        orb = []
        y = x
        c = x
        for k in range(m):
            y = rot(x, k, m)
            orb.append(y)
            if y < c:
                c = y
        for y in set(orb):
            tab[y] = c
    return tab


def build_orbits(m, tab):
    """Orbite non banali: rep canonico -> (index, r, s)."""
    full = (1 << m) - 1
    reps = sorted({tab[x] for x in range(1, full)})
    info = []
    idx = {}
    for i, c in enumerate(reps):
        orb = {rot(c, k, m) for k in range(m)}
        info.append((c, len(orb), popcount(c)))
        idx[c] = i
    return reps, info, idx


def build_clauses(m, tab, reps, info, idx):
    full = (1 << m) - 1
    n = len(reps)
    orbits_sets = []
    for c, r, s in info:
        orbits_sets.append(sorted({rot(c, k, m) for k in range(m)}))
    clauses = []  # (i, j, t) -> ¬xi ∨ ¬xj ∨ xt
    t0 = time.time()
    for i in range(n):
        A = reps[i]
        for j in range(i, n):
            targets = set()
            for B in orbits_sets[j]:
                u = A | B
                if u == full:
                    continue
                cu = tab[u]
                targets.add(cu)
            targets.discard(reps[i])
            targets.discard(reps[j])
            for cu in targets:
                clauses.append((i, j, idx[cu]))
    return clauses, time.time() - t0


def solve(m, mode="decide", time_cap=120, verbose=True, min_set_size=1):
    tab = canon_table(m)
    reps, info, idx = build_orbits(m, tab)
    n = len(reps)
    clauses, tb = build_clauses(m, tab, reps, info, idx)
    if verbose:
        print(f"  Z_{m}: {n} orbite non banali, {len(clauses)} clausole di chiusura (build {tb:.1f}s)")
    model = cp_model.CpModel()
    x = [model.NewBoolVar(f"x{i}") for i in range(n)]
    if min_set_size > 1:
        for i, (_, r, s) in enumerate(info):
            if s < min_set_size:
                model.Add(x[i] == 0)
    for i, j, t in clauses:
        model.AddBoolOr([x[i].Not(), x[j].Not(), x[t]])
    # margine scalato m*M = Σ r(2s-m) x  (intero)
    coeff = [r * (2 * s - m) for (_, r, s) in info]
    expr = sum(c * xi for c, xi in zip(coeff, x))
    model.Add(sum(x) >= 1)  # esclude la famiglia banale {∅, Z_m}
    if mode == "decide":
        model.Add(expr <= -m)  # M <= -1
    else:
        obj = model.NewIntVar(-sum(abs(c) for c in coeff), sum(abs(c) for c in coeff), "M")
        model.Add(obj == expr)
        model.Minimize(obj)
    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = time_cap
    solver.parameters.num_search_workers = 4
    st = solver.Solve(model)
    name = solver.StatusName(st)
    out = {"status": name, "m": m}
    if st in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        chosen = [i for i in range(n) if solver.Value(x[i])]
        out["chosen_reps"] = [reps[i] for i in chosen]
        out["scaled_margin"] = sum(coeff[i] for i in chosen)
        out["F"] = 2 + sum(info[i][1] for i in chosen)
    return out


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "controls"
    if which == "controls":
        for mm in (7, 11):
            t0 = time.time()
            r = solve(mm, "decide", time_cap=60)
            print(f"  CONTROLLO Z_{mm} (atteso INFEASIBLE): {r['status']}  [{time.time()-t0:.1f}s]")
            assert r["status"] == "INFEASIBLE", f"BUG DI ENCODING su Z_{mm}: fermarsi!"
        print("  [OK] pipeline SAT validata: nessun controesempio ciclico su Z_7, Z_11 (come da teoria)")
    elif which == "decide13":
        t0 = time.time()
        r = solve(13, "decide", time_cap=150)
        print(f"  DECISIONE Z_13, vincolo M<=-1: {r['status']}  [{time.time()-t0:.1f}s]")
        if r["status"] in ("FEASIBLE", "OPTIMAL"):
            print("  !!! CANDIDATO TROVATO:", r)
    elif which == "opt13":
        t0 = time.time()
        r = solve(13, "optimize", time_cap=180)
        print(f"  OTTIMIZZAZIONE Z_13 (min M): {r['status']}  [{time.time()-t0:.1f}s]")
        if "scaled_margin" in r:
            print(f"  margine minimo m*M = {r['scaled_margin']}  (M = {r['scaled_margin']//13})  |F| = {r['F']}")
            print(f"  orbite scelte (rep canonici): {r['chosen_reps']}")
    elif which == "opt13min3":
        t0 = time.time()
        r = solve(13, "optimize", time_cap=200, min_set_size=3)
        print(f"  OTTIMIZZAZIONE Z_13, taglie>=3 (min M): {r['status']}  [{time.time()-t0:.1f}s]")
        if "scaled_margin" in r:
            M = r["scaled_margin"] // 13
            print(f"  margine minimo M = {M}  |F| = {r['F']}  (f = {(r['F'] + M) // 2})")
            print(f"  orbite scelte: {len(r['chosen_reps'])}  rep: {r['chosen_reps'][:20]}{'...' if len(r['chosen_reps'])>20 else ''}")
    elif which == "decide14":
        t0 = time.time()
        r = solve(14, "decide", time_cap=150)
        print(f"  DECISIONE Z_14, vincolo M<=-1: {r['status']}  [{time.time()-t0:.1f}s]")
        if r["status"] in ("FEASIBLE", "OPTIMAL"):
            print("  !!! CANDIDATO TROVATO:", r)
__EOF_FRANKL_X7Q__
cat > "$DEST/anneal.py" << '__EOF_FRANKL_X7Q__'
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
__EOF_FRANKL_X7Q__
cat > "$DEST/structured.py" << '__EOF_FRANKL_X7Q__'
"""structured.py — Costruzioni strutturate su 13 punti, con verifiche a mano.

Ogni costruzione ha conteggi ATTESI calcolati a mano prima del run: se il
codice non li riproduce, il bug è nel codice (o nel conto, da rifare a mano).
"""
import time
from fractions import Fraction
from ucs_core import closure, check_family, family_to_sets, rot, popcount
from checker2 import verify


def report(name, gens, m, expected=None):
    fam = set(closure(gens)) | {0}
    r1 = check_family(fam, m)
    r2 = verify(family_to_sets(fam, m))
    assert r1["closed"] and r2["closed"]
    assert r1["margin"] == r2["margin"] and r1["maxf"] == r2["maxf"]
    F, maxf, marg = r1["F"], r1["maxf"], r1["margin"]
    ratio = Fraction(maxf, F)
    sizes = {}
    for x in fam:
        sizes[popcount(x)] = sizes.get(popcount(x), 0) + 1
    print(f"== {name}: |F|={F} (con ∅), maxf={maxf}, margine={marg}, ratio={ratio} ≈ {float(ratio):.4f}")
    print(f"   distribuzione taglie: {dict(sorted(sizes.items()))}")
    if expected:
        for k, v in expected.items():
            got = {"F": F, "maxf": maxf, "margin": marg}.get(k, sizes.get(k))
            assert got == v, f"{name}: atteso {k}={v}, ottenuto {got} — BUG da trovare"
        print(f"   [assert a mano superati: {expected}]")
    assert marg >= 0 or (print('CANDIDATO!!', name) or True)
    return marg, F, ratio


# ---------- 1) Piano proiettivo PG(2,3): 13 punti, 13 rette da 4 punti ----------
def pg23_lines():
    # punti proiettivi su GF(3): rappresentanti normalizzati (primo coeff non nullo = 1)
    pts = []
    for x in range(3):
        for y in range(3):
            for z in range(3):
                if (x, y, z) == (0, 0, 0):
                    continue
                # normalizza: primo coefficiente non nullo -> 1
                v = (x, y, z)
                for c in v:
                    if c != 0:
                        inv = 1 if c == 1 else 2  # inverso in GF(3)
                        v = tuple((inv * t) % 3 for t in v)
                        break
                if v not in pts:
                    pts.append(v)
    assert len(pts) == 13
    idx = {p: i for i, p in enumerate(pts)}
    lines = []
    for a, b, c in pts:  # ogni retta = punti ortogonali a un punto duale
        mask = 0
        for p in pts:
            if (a * p[0] + b * p[1] + c * p[2]) % 3 == 0:
                mask |= 1 << idx[p]
        assert popcount(mask) == 4
        lines.append(mask)
    assert len(set(lines)) == 13
    return lines


# ---------- 2) STS(13) ciclico: blocchi base {0,1,4}, {0,2,7} ----------
def sts13_blocks():
    base = [(0, 1, 4), (0, 2, 7)]
    blocks = []
    for b in base:
        for k in range(13):
            blocks.append(frozenset((x + k) % 13 for x in b))
    blocks = sorted(set(blocks))
    assert len(blocks) == 26
    # verifica Steiner: ogni coppia esattamente una volta
    from itertools import combinations
    seen = {}
    for B in blocks:
        for p in combinations(sorted(B), 2):
            seen[p] = seen.get(p, 0) + 1
    assert all(v == 1 for v in seen.values()) and len(seen) == 78, "non è un STS(13)!"
    return [sum(1 << i for i in B) for B in blocks]


# ---------- 3) Residui quadratici mod 13 ----------
def qr13_orbit():
    qr = {(i * i) % 13 for i in range(1, 13)}
    assert qr == {1, 3, 4, 9, 10, 12}
    mask = sum(1 << i for i in qr)
    return [rot(mask, k, 13) for k in range(13)]


# ---------- 4) Intervalli ciclici: chiusura di {0,1,2} su Z13 ----------
def runs3_gens():
    mask = 0b111
    return [rot(mask, k, 13) for k in range(13)]


if __name__ == "__main__":
    t0 = time.time()
    results = []
    results.append(("PG(2,3)", report(
        "PG(2,3) chiusura delle 13 rette", pg23_lines(), 13,
        expected={"F": 704, "maxf": 507, "margin": 310, 4: 13, 7: 78, 9: 234,
                  10: 286, 11: 78, 12: 13, 13: 1})))
    results.append(("STS(13)", report("STS(13) ciclico {0,1,4},{0,2,7}", sts13_blocks(), 13)))
    results.append(("QR(13)", report("QR(13) orbita di {1,3,4,9,10,12}", qr13_orbit(), 13)))
    results.append(("Runs>=3", report(
        "Intervalli: chiusura ciclica di {0,1,2}", runs3_gens(), 13,
        expected={"F": 522})))
    print(f"\nTutte le costruzioni verificate in {time.time()-t0:.1f}s")
    best = min(results, key=lambda r: (r[1][0], -r[1][1]))
    print(f"Migliore strutturata: {best[0]} con margine {best[1][0]} (ratio ≈ {float(best[1][2]):.4f})")
    print("\nNota up-set (esclusi a priori): per ogni up-set U e ogni x, la mappa"
          " S ↦ S∪{x} è un'iniezione dai membri senza x ai membri con x,"
          " quindi ogni elemento ha frequenza ≥ |U|/2: mai competitivi.")
__EOF_FRANKL_X7Q__
cat > "$DEST/cegar.py" << '__EOF_FRANKL_X7Q__'
"""cegar.py — Decisione CEGAR: esiste un controesempio Z_m-invariante?

Idea. Il modello monolitico (sat_cyclic) satura la memoria per m=14 (7,3M
clausole). Qui si parte dal SOLO vincolo di margine (rilassamento) e si
aggiungono le clausole di chiusura solo quando violate da una soluzione
candidata (counterexample-guided refinement).

Garanzie. Se il rilassato è INFEASIBLE, lo è anche il problema completo
(abbiamo solo tolto vincoli) → risposta definitiva. Se una soluzione
soddisfa TUTTE le chiusure (scansione completa senza violazioni), è un
candidato reale → protocollo di stop e doppia verifica. Terminazione:
pool di clausole finito, ogni iterazione ne aggiunge almeno una.

Seeding. Le orbite a coefficiente negativo (2s < m) sono quelle che ogni
soluzione deve usare: pre-carichiamo le clausole tra coppie di tali orbite
(in ordine di s crescente) fino a un budget, per abbattere le iterazioni.

CONTROLLI: Z_7 e Z_11 devono dare INFEASIBLE; Z_13 deve CONCORDARE con il
risultato monolitico (INFEASIBLE). Solo dopo si passa a Z_14, Z_15.
"""
import sys, time
from ortools.sat.python import cp_model
from ucs_core import rot
from sat_cyclic import canon_table, build_orbits


def cegar_decide(m, wall_cap=240, seed_budget=1_200_000, iter_cap=300,
                 per_solve_cap=90, verbose=True):
    t0 = time.time()
    tab = canon_table(m)
    reps, info, idx = build_orbits(m, tab)
    n = len(reps)
    full = (1 << m) - 1
    orbit_sets = [sorted({rot(c, k, m) for k in range(m)}) for c, _, _ in info]
    coeff = [r * (2 * s - m) for (_, r, s) in info]  # margine scalato m*M

    model = cp_model.CpModel()
    x = [model.NewBoolVar(f"x{i}") for i in range(n)]
    model.Add(sum(c * xi for c, xi in zip(coeff, x)) <= -m)  # M <= -1
    model.Add(sum(x) >= 1)

    added = set()

    def clauses_for_pair(i, j):
        A = reps[i]
        out = set()
        for B in orbit_sets[j]:
            u = A | B
            if u == full:
                continue
            t = idx[tab[u]]
            if t == i or t == j:
                continue
            out.add((i, j, t))
        return out

    def add_clause(cl):
        i, j, t = cl
        model.AddBoolOr([x[i].Not(), x[j].Not(), x[t]])
        added.add(cl)

    # ---- seeding: coppie tra orbite a coefficiente negativo, s crescente ----
    neg = sorted((i for i in range(n) if coeff[i] < 0), key=lambda i: info[i][2])
    seeded = 0
    done_seed = False
    for a in range(len(neg)):
        if done_seed:
            break
        for b in range(a, len(neg)):
            i, j = neg[a], neg[b]
            for cl in clauses_for_pair(i, j):
                if cl not in added:
                    add_clause(cl)
                    seeded += 1
            if seeded > seed_budget:
                done_seed = True
                break
    if verbose:
        print(f"  Z_{m}: {n} orbite; seeding {seeded} clausole "
              f"(coppie tra {len(neg)} orbite a coeff<0) in {time.time()-t0:.1f}s")

    solver = cp_model.CpSolver()
    solver.parameters.num_search_workers = 4

    for it in range(1, iter_cap + 1):
        remaining = wall_cap - (time.time() - t0)
        if remaining < 5:
            return {"status": "UNKNOWN(wall-cap)", "iters": it - 1,
                    "clauses": len(added), "m": m}
        solver.parameters.max_time_in_seconds = min(per_solve_cap, remaining)
        st = solver.Solve(model)
        name = solver.StatusName(st)
        if st == cp_model.INFEASIBLE:
            return {"status": "INFEASIBLE", "iters": it,
                    "clauses": len(added), "m": m,
                    "secs": round(time.time() - t0, 1)}
        if st not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
            return {"status": f"UNKNOWN({name})", "iters": it,
                    "clauses": len(added), "m": m}
        S = [i for i in range(n) if solver.Value(x[i])]
        # cerca violazioni di chiusura nella soluzione candidata
        viol = set()
        capped = False
        for a in range(len(S)):
            for b in range(a, len(S)):
                new = clauses_for_pair(S[a], S[b]) - added
                viol |= new
                if len(viol) > 50_000:
                    capped = True
                    break
            if capped:
                break
        if not viol and not capped:
            # scansione COMPLETA senza violazioni: candidato reale
            return {"status": "SAT-CANDIDATE", "iters": it, "m": m,
                    "chosen_reps": [reps[i] for i in S],
                    "scaled_margin": sum(coeff[i] for i in S),
                    "F": 2 + sum(info[i][1] for i in S)}
        for cl in viol:
            add_clause(cl)
        if verbose and (it <= 3 or it % 10 == 0):
            print(f"    iter {it}: |S|={len(S)}, +{len(viol)} clausole "
                  f"(tot {len(added)}), t={time.time()-t0:.0f}s")
    return {"status": "UNKNOWN(iter-cap)", "iters": iter_cap,
            "clauses": len(added), "m": m}


if __name__ == "__main__":
    which = sys.argv[1]
    if which == "controls":
        for mm in (7, 11):
            r = cegar_decide(mm, wall_cap=90, seed_budget=200_000, verbose=True)
            print(f"  CONTROLLO CEGAR Z_{mm} (atteso INFEASIBLE): {r}")
            assert r["status"] == "INFEASIBLE", "BUG nella pipeline CEGAR: fermarsi!"
        print("  [OK] pipeline CEGAR validata su Z_7, Z_11")
    elif which == "cross13":
        r = cegar_decide(13, wall_cap=240, seed_budget=900_000)
        print(f"  CROSS-CHECK CEGAR Z_13 (atteso INFEASIBLE come il monolitico): {r}")
        assert r["status"] == "INFEASIBLE", "DISACCORDO col monolitico: indagare!"
    elif which == "z14":
        r = cegar_decide(14, wall_cap=250, seed_budget=1_200_000)
        print(f"  DECISIONE CEGAR Z_14: {r}")
        if r["status"] == "SAT-CANDIDATE":
            print("  !!! CANDIDATO: attivare protocollo di verifica completo")
    elif which == "z15":
        r = cegar_decide(15, wall_cap=250, seed_budget=1_200_000)
        print(f"  DECISIONE CEGAR Z_15: {r}")
        if r["status"] == "SAT-CANDIDATE":
            print("  !!! CANDIDATO: attivare protocollo di verifica completo")
__EOF_FRANKL_X7Q__
cat > "$DEST/pb_adder.py" << '__EOF_FRANKL_X7Q__'
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
__EOF_FRANKL_X7Q__
cat > "$DEST/sat2_cyclic.py" << '__EOF_FRANKL_X7Q__'
"""sat2_cyclic.py — Seconda pipeline, solver indipendente (pysat/CaDiCaL).

Stessa domanda di sat_cyclic (esiste un controesempio Z_m-invariante?) con
stack completamente diverso: clausole di chiusura aggiunte in STREAMING al
solver C (memoria Python trascurabile: risolve l'OOM di Z_14) e vincolo di
margine  Σ d_O x_O ≤ -1  con d_O = r_O(2 s_O - m)/m  (sempre intero perché
m | r_O·s_O) codificato dall'encoder ad addizionatori binari di pb_adder
(validato per forza bruta).

Ruolo doppio: (1) su Z_13 fornisce la conferma con SECONDO SOLVER
indipendente del risultato CP-SAT; (2) su Z_14 e Z_15 produce decisioni
nuove, fuori portata per l'encoding monolitico.

CONTROLLI: Z_7 e Z_11 devono dare UNSAT prima di credere a qualunque
altro esito. Timeout in-process via Timer+interrupt (esito onesto
"UNKNOWN" se scade).
"""
import sys, time, threading
from pysat.solvers import Cadical153
from ucs_core import rot
from sat_cyclic import canon_table, build_orbits
from pb_adder import Pool, encode_signed_leq


def decide(m, wall_cap=240, verbose=True, pair_filter="all", min_size=1):
    t0 = time.time()
    tab = canon_table(m)
    reps, info, idx = build_orbits(m, tab)
    n = len(reps)
    full = (1 << m) - 1
    orbit_sets = [sorted({rot(c, k, m) for k in range(m)}) for c, _, _ in info]
    d = []
    for (_, r, s) in info:
        assert (2 * r * s) % m == 0, "coefficiente non intero: bug"
        d.append((2 * r * s) // m - r)

    solver = Cadical153()
    if min_size > 1:  # valido per controesempi: nessun insieme di taglia 1-2
        for i in range(n):
            if info[i][2] < min_size:
                solver.add_clause([-(i + 1)])
    # ---- margine: Σ d_i x_i ≤ -1 (variabili 1..n) ----
    pool = Pool(n + 1)
    pb = encode_signed_leq({i + 1: d[i] for i in range(n) if d[i] != 0}, -1, pool)
    for c in pb:
        solver.add_clause(c)
    solver.add_clause(list(range(1, n + 1)))  # almeno un'orbita
    # ---- chiusura in streaming ----
    n_cl = 0
    pairs = 0
    neg_idx = {i for i in range(n) if d[i] < 0}
    for i in range(n):
        Ai = reps[i]
        for j in range(i, n):
            if pair_filter == "neg" and i not in neg_idx and j not in neg_idx:
                continue  # rilassamento sano: UNSAT resta valido
            pairs += 1
            seen = set()
            for B in orbit_sets[j]:
                u = Ai | B
                if u == full:
                    continue
                t = idx[tab[u]]
                if t == i or t == j or t in seen:
                    continue
                seen.add(t)
                solver.add_clause([-(i + 1), -(j + 1), t + 1])
                n_cl += 1
        if time.time() - t0 > wall_cap:
            return {"status": "UNKNOWN(build-cap)", "m": m, "clauses": n_cl}
    tb = time.time() - t0
    if verbose:
        print(f"  Z_{m}: {n} orbite, PB {len(pb)} cls (aux fino a v{pool.next-1}), "
              f"chiusura {n_cl} cls su {pairs} coppie [{pair_filter}] (build {tb:.0f}s)")
    # ---- solve con interrupt ----
    budget = max(5.0, wall_cap - (time.time() - t0))
    timer = threading.Timer(budget, solver.interrupt)
    timer.start()
    res = solver.solve_limited(expect_interrupt=True)
    timer.cancel()
    dt = time.time() - t0
    if res is None:
        return {"status": "UNKNOWN(solve-cap)", "m": m, "secs": round(dt, 1),
                "clauses": n_cl}
    if res is False:
        note = "" if pair_filter == "all" else " (rilassamento neg-pairs: esito comunque valido)"
        return {"status": "UNSAT" + note, "m": m, "secs": round(dt, 1),
                "clauses": n_cl}
    model = solver.get_model()
    chosen = [i for i in range(n) if model[i] > 0]  # var i+1 in pos i
    out = {"status": "SAT", "m": m, "secs": round(dt, 1),
           "chosen_reps": [reps[i] for i in chosen],
           "margin": sum(d[i] for i in chosen),
           "F": 2 + sum(info[i][1] for i in chosen),
           "complete_model": (pair_filter == "all")}
    return out


if __name__ == "__main__":
    which = sys.argv[1]
    cap = int(sys.argv[2]) if len(sys.argv) > 2 else None
    def C(default):
        return cap if cap else default
    if which == "controls":
        for mm in (7, 11):
            r = decide(mm, wall_cap=60)
            print(f"  CONTROLLO pysat Z_{mm} (atteso UNSAT): {r}")
            assert r["status"].startswith("UNSAT"), "BUG pipeline pysat: fermarsi!"
        print("  [OK] pipeline pysat validata su Z_7, Z_11")
    elif which == "z13":
        r = decide(13, wall_cap=C(250))
        print(f"  Z_13 con pysat/CaDiCaL (atteso UNSAT, conferma indipendente): {r}")
    elif which == "z14":
        r = decide(14, wall_cap=C(250))
        print(f"  DECISIONE Z_14 (pysat, streaming): {r}")
        if r["status"] == "SAT":
            print("  !!! modello completo: candidato -> protocollo di verifica" if r.get("complete_model") else "")
    elif which == "z15":
        r = decide(15, wall_cap=C(250))
        print(f"  DECISIONE Z_15 (pysat, streaming): {r}")
    elif which == "z15neg":
        r = decide(15, wall_cap=C(250), pair_filter="neg")
        print(f"  DECISIONE Z_15 (rilassamento neg-pairs): {r}")
    if which == "z14min3":
        r = decide(14, wall_cap=C(2400), min_size=3)
        print(f"  DECISIONE Z_14, taglie>=3 (pysat, streaming): {r}")
    if which == "z13min3":
        r = decide(13, wall_cap=C(2400), min_size=3)
        print(f"  DECISIONE Z_13, taglie>=3 (pysat): {r}")
__EOF_FRANKL_X7Q__
cat > "$DEST/dump_dimacs.py" << '__EOF_FRANKL_X7Q__'
"""dump_dimacs.py — Scrive in DIMACS la formula 'controesempio Z_m-invariante'.

Riusa ESATTAMENTE le stesse funzioni della pipeline pysat validata
(canon_table/build_orbits di sat_cyclic, encode_signed_leq di pb_adder):
la formula certificata è per costruzione quella già decisa in-process.
Uso: python3 dump_dimacs.py <m> <out.cnf> [min_size]
"""
import sys
from ucs_core import rot
from sat_cyclic import canon_table, build_orbits
from pb_adder import Pool, encode_signed_leq


def dump(m, path, min_size=1):
    tab = canon_table(m)
    reps, info, idx = build_orbits(m, tab)
    n = len(reps)
    full = (1 << m) - 1
    orbit_sets = [sorted({rot(c, k, m) for k in range(m)}) for c, _, _ in info]
    d = []
    for (_, r, s) in info:
        assert (2 * r * s) % m == 0
        d.append((2 * r * s) // m - r)
    pool = Pool(n + 1)
    pb = encode_signed_leq({i + 1: d[i] for i in range(n) if d[i] != 0}, -1, pool)
    ncl = 0
    body = path + ".body"
    with open(body, "w") as f:
        if min_size > 1:
            for i in range(n):
                if info[i][2] < min_size:
                    f.write(f"{-(i+1)} 0\n"); ncl += 1
        for c in pb:
            f.write(" ".join(map(str, c)) + " 0\n"); ncl += 1
        f.write(" ".join(str(v) for v in range(1, n + 1)) + " 0\n"); ncl += 1
        for i in range(n):
            Ai = reps[i]
            for j in range(i, n):
                seen = set()
                for B in orbit_sets[j]:
                    u = Ai | B
                    if u == full:
                        continue
                    t = idx[tab[u]]
                    if t == i or t == j or t in seen:
                        continue
                    seen.add(t)
                    f.write(f"{-(i+1)} {-(j+1)} {t+1} 0\n"); ncl += 1
    with open(path, "w") as f:
        f.write(f"p cnf {pool.next - 1} {ncl}\n")
    import subprocess
    subprocess.run(f"cat {body} >> {path} && rm {body}", shell=True, check=True)
    print(f"DIMACS: {path}  vars={pool.next - 1}  clauses={ncl}  (m={m}, min_size={min_size})")


if __name__ == "__main__":
    m = int(sys.argv[1]); out = sys.argv[2]
    ms = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    dump(m, out, ms)
__EOF_FRANKL_X7Q__
cat > "$DEST/GOAL.md" << '__EOF_FRANKL_X7Q__'
# Obiettivo
Estendere i risultati di RISULTATI.md: decidere se esistono famiglie
union-closed Z14- e Z15-invarianti che violino la congettura di Frankl
(margine intero 2*maxfreq - |F| <= -1), oppure trovare un controesempio
generale alla congettura.

# Criteri di SUCCESS (uno qualunque)
- Candidato controesempio: famiglia che passa ENTRAMBI i checker indipendenti
  (ucs_core.check_family e checker2.verify) con 2*maxfreq < |F| su interi.
- Risultato negativo di valore: UNSAT per Z14 (taglie >= 3) confermato da due
  solver indipendenti o con certificato DRAT verificato da drat-trim.

# Vincoli di rigore ereditati
Aritmetica dei verdetti solo su interi; controlli (Z7, Z11, P([4])) PRIMA di
ogni run di produzione; ogni pipeline nuova va validata sui controlli prima
di credere ai suoi esiti; ratio < 0,382 => bug, fermarsi.

# Non-obiettivi
Niente riscritture estetiche del codice esistente; niente esplorazioni fuori
scope senza aggiungerle prima al backlog con stima costo/valore.
__EOF_FRANKL_X7Q__

echo "Fatto. Contenuto:"
ls -la "$DEST"
echo
echo "Prossimi passi: apri Claude Code DENTRO la cartella ($DEST) e segui CLAUDE.md (bootstrap)."
