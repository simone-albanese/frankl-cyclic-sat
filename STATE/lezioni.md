# Lezioni — memoria del progetto
Una lezione per voce, riga di sintesi in testa. Si aggiorna una voce esistente
invece di duplicarla; le voci rivelatesi sbagliate si cancellano.

## AMBIENTE

### `python3` nudo NON è l'interprete del progetto
In shell non interattiva `python3` risolve a Python 3.14 di Homebrew, che non ha
né `ortools` né `pysat`. L'interprete del progetto è `.venv/bin/python3`
(Python 3.13.12). **Ogni comando Python va scritto con `.venv/bin/python3`**
(o `$PY` dopo `source STATE/hardware.env`). Confermato al bootstrap: import di
`cp_model` e `Cadical153` OK solo dal venv. Attenzione: `python3 --version` può
rispondere "3.13.12" anche fuori dal venv (Homebrew ha la stessa minor) — la
versione NON è una prova, va provato l'import.

### Homebrew è "externally managed": niente `pip install` di sistema
Installare fuori dal venv fallisce (PEP 668) o inquina il Python di sistema.
Tutto ciò che serve si installa con `.venv/bin/python3 -m pip install ...`.

### Workspace non "trusted" ⇒ `permissions.allow` ignorato IN BLOCCO
Scoperto il 2026-08-11 nella prima iterazione di prova, causa accertata leggendo
`results/logs/loop.log`:

    Ignoring 14 permissions.allow entries from .claude/settings.json:
    this workspace has not been trusted.

Effetto: in sessione driver ogni esecuzione Bash veniva negata (nemmeno
`osascript` per le notifiche), mentre le scritture di file passavano. **Non era
un problema di sintassi delle regole**: una prima diagnosi aveva concluso che la
regola nuda `"Bash"` non fosse onorata e proponeva ~40 regole a prefisso — sbagliata,
sarebbero state ignorate anch'esse, perché il filtro è sul workspace, non sulla regola.

Correzione adottata (in `scripts/loop.sh`): i permessi si passano **sulla riga di
comando** — `--allowedTools ...` e `--disallowedTools "Bash(sudo:*)"` — perché i
flag CLI sono onorati anche in un workspace non fidato (verificato su cartella
canarino prima di adottarli). Non si usa `--dangerously-skip-permissions`.

Complemento facoltativo, solo l'umano può farlo: aprire una volta Claude Code
interattivo nella cartella e accettare il dialogo di fiducia (oppure impostare
`projects["…/frankl"].hasTrustDialogAccepted: true` in `~/.claude.json`). Da quel
momento vale anche `permissions.allow` di `.claude/settings.json`. Il loop non ne
dipende: funziona in entrambi i casi.

Nota non riverificata: la sessione driver ha riportato che le era negata anche la
scrittura di `.claude/settings.json` (plausibile protezione contro l'auto-concessione
di permessi). Irrilevante ora, visto che i permessi arrivano dai flag.

### `env` di settings.json: nessuna espansione, e SOSTITUISCE la variabile
`"PATH": "…:${PATH}"` non viene espanso (resta testo letterale) e il valore
rimpiazza il PATH ereditato: scriverlo incompleto fa sparire `/usr/bin` e uccide
hook e comandi di sistema (verificato: un hook moriva con `node: command not found`).
Il PATH va quindi scritto **per intero**. Al contrario di `permissions.allow`, la
chiave `env` è applicata anche in un workspace non fidato.

### Command Line Tools presenti (git/make/clang)
Verificati al bootstrap: `/Library/Developer/CommandLineTools` v26.2. Quindi i
task che richiedono compilazione (CaDiCaL 2.x, drat-trim) sono eseguibili senza
intervento umano.

## MODELLO

### Il progetto gira solo su `claude-fable-5` — pin triplo
Flag `--model claude-fable-5` in `scripts/loop.sh`, chiave `"model"` in
`.claude/settings.json`, `/model fable` in interattivo. **Nessun
`fallbackModel`** (verificato: assente sia nei settings globali sia in quelli di
progetto). Se compare un avviso di cambio modello: fermare il task, 🔴 in
SITUAZIONE.md, annotare in HANDOFF, non prendere decisioni di calcolo sul
modello degradato.

### Effort e contesto del loop si governano da `loop.sh`, non dai settings
I settings globali dell'utente impostano `effortLevel: xhigh` e caricano plugin
e hook su ogni sessione. Per il loop non presidiato entrambi sono peso morto:
a effort massimo su ~200 iterazioni si esaurisce il monte-token (e il driver si
ferma per "limiti"), e i server MCP dei plugin aggiungono decine di definizioni
di strumenti inutili al budget di contesto. Il driver quindi passa
`--strict-mcp-config` (nessun MCP) e `--effort` letto da `STATE/effort.txt`
(default `medium`, `high` per i task di progettazione T7/T8/T10). Le sessioni
interattive dell'umano nella cartella restano invariate.
**Non usare `--bare`** per togliere gli hook: legge l'autenticazione solo da
`ANTHROPIC_API_KEY` (mai OAuth né portachiavi) ⇒ ogni iterazione fallirebbe.
Misura di riferimento: l'iterazione T1 completa è durata 96 s con gli hook
attivi, quindi gli hook non sono il collo di bottiglia. Se un hook dovesse
bloccare una scrittura legittima, annotarlo qui e segnalarlo in HANDOFF.

## METODO

### Prima di dichiarare una causa, leggere il log del driver
La diagnosi sbagliata sui permessi nasce dall'aver inferito la causa dal
comportamento ("i comandi vengono negati ⇒ le regole sono scritte male") invece
che dal messaggio esplicito già presente in `results/logs/loop.log`. Regola:
davanti a un blocco infrastrutturale, `grep` sul log del driver **prima** di
formulare ipotesi.

### Aritmetica dei verdetti solo su interi
Condizione di controesempio: `2*maxfreq < |F|`, mai rapporti in virgola mobile.
Il float è ammesso solo come guida euristica interna (es. `anneal.py`), mai in
un verdetto.

### Controlli PRIMA di ogni run di produzione
`controls.py` (P([4]), validatore, detector, accordo checker1/checker2), più i
controlli di pipeline Z7/Z11 del solver che si sta per usare. Una pipeline nuova
non è credibile finché non li supera. Tripwire: ratio < 0,382 ⇒ bug, fermarsi.

### `sat_cyclic.solve()` usa 4 worker CP-SAT, il budget ne prevede 3
`num_search_workers = 4` è cablato nel sorgente; `CORES_JOB` = 3. Su M4 (4
P-core) la differenza è tollerabile, ma per i run lunghi in background conviene
passare da un wrapper `-c` che imposti il numero di worker, invece di modificare
i sorgenti esistenti (non-obiettivo: niente riscritture estetiche).

## Toolchain di certificazione: binari pronti e catena validata (2026-08-11)
Sintesi: usare `tools/cadical/build/cadical` e `tools/drat-trim/drat-trim`; catena validata con `--no-binary`.
- CaDiCaL compilato in `tools/cadical/build/cadical`; drat-trim in `tools/drat-trim/drat-trim`.
- Catena validata end-to-end su Z7 e Z11: `dump_dimacs.py M out.cnf [min_size]` → `cadical --no-binary out.cnf out.drat` (exit 20 = UNSAT) → `drat-trim out.cnf out.drat` (exit 0 + `s VERIFIED`).
- `dump_dimacs.py` non ha `--help`: argomenti posizionali `m out [min_size]`.
- Restare su `--no-binary` anche in produzione: è la variante validata (prove più grandi ma formato certo per drat-trim).

## Non modificare mai sul posto uno script bash in esecuzione
Bash legge lo script in modo incrementale, per offset di byte, non tutto in memoria:
inserire o togliere righe mentre gira fa riprendere il processo a un offset sbagliato,
eseguendo testo troncato o spostato. Vale per `scripts/loop.sh`, che gira per ore.
**Come si fa invece:** scrivere una copia (`loop.sh.new`), validarla con `bash -n`,
allineare i permessi con `chmod $(stat -f %Lp originale)`, poi `mv` — la rename e'
atomica e sostituisce la voce di directory, mentre il processo in corso continua a
leggere il vecchio inode fino alla fine. Verificare con `stat -f %i` che l'inode sia
cambiato e con `ps` che il driver sia ancora vivo. La modifica entra in vigore al
rilancio successivo, mai a caldo: se serve subito, va fermato il loop (PAUSE) e rilanciato.

## Il sed di macOS (BSD) non conosce l'alternanza `\|`
Un `sed -n 's/^\(AAA\|BBB\)=.*/\1/p'` che su Linux estrae nomi di variabili, su macOS
**non restituisce nulla e non segnala errore**: BSD sed nelle regex base non supporta
`\|`. Un ciclo `for v in $(quel sed)` gira allora a vuoto e il codice sembra funzionare
mentre non fa niente — il caso peggiore, un fallimento silenzioso.
**Rimedio:** `grep -oE '^(AAA|BBB)'` (ERE, portabile e gia' usato altrove nel progetto),
oppure `sed -E`. Regola generale per questo progetto: ogni filtro di testo va provato
sul suo output reale, non dato per buono perche' "la regex e' giusta".

## Lanciare il loop da dentro una sessione Claude Code contamina le sessioni figlie
Se `scripts/loop.sh` parte da un'altra sessione Claude (o da un agente) invece che da un
Terminale pulito, le `CLAUDE_CODE_*`, `CLAUDECODE`, `CLAUDE_EFFORT`, `CLAUDE_PID`,
`CLAUDE_PLUGIN_DATA`, `CODEX_*` del padre vengono ereditate da ogni `claude -p` figlio:
`CLAUDE_EFFORT` scavalca l'--effort letto da `STATE/effort.txt` (sorveglianza
amministrativa eseguita a effort massimo), e socket/ID di sessione puntano alla sessione
sbagliata. Verificato: figlio con 11 variabili ereditate prima della correzione, 0 dopo.
**Rimedio, gia' applicato:** `loop.sh` si ripulisce da solo in testa (deviazione 9), cosi'
e' corretto da qualunque contesto venga lanciato. `ANTHROPIC_*` NON si tocca: e' l'auth.
`env -u ...` dal chiamante NON basta: in zsh l'espansione non fa word-splitting e i flag
arrivano a `env` come un unico argomento.
