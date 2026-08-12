#!/bin/bash
# scripts/loop.sh — driver esterno del ciclo.
# È LUI a garantire il contesto pulito: ogni giro apre una sessione claude NUOVA,
# lo stato passa solo attraverso i file di STATE/ e results/.
#
# Si ferma da solo su: DONE (risultato raggiunto), BLOCKED (serve l'umano),
# PAUSE (stop pulito chiesto dall'umano), 4 fallimenti consecutivi (limiti/token).
#
# Uso:            bash scripts/loop.sh
# Una sola iterazione (prova):  MAX_ITER=1 bash scripts/loop.sh
# Stop pulito da un altro terminale:  echo PAUSE > STATE/status.txt
#
# Deviazioni dal modello in CLAUDE.md (tutte additive, semantica invariata):
#  1. `cd` alla radice del progetto -> lanciabile da qualunque directory;
#  2. stato PAUSE + MAX_ITER da variabile d'ambiente -> stop pulito e prova a 1 giro;
#  3. output di ogni iterazione anche su results/logs/loop.log (`tee`) -> monitoraggio
#     con `tail -f`; `pipefail` preserva il codice di uscita di claude attraverso il tee;
#  4. dopo il 4° fallimento esce subito invece di dormire 5 minuti inutilmente;
#  5. permessi passati sulla RIGA DI COMANDO (--allowedTools) e non solo via
#     .claude/settings.json: in un workspace non ancora "trusted" Claude Code
#     IGNORA in blocco permissions.allow ("Ignoring N permissions.allow entries
#     ... this workspace has not been trusted") e il loop non puo' eseguire
#     nulla. I flag CLI valgono comunque. NON si usa --dangerously-skip-permissions.
#  6. venv in testa al PATH anche qui, cosi' "python3" e' quello giusto perfino
#     se settings.json non venisse letto;
#  7. igiene di contesto e di budget (regole 1 e 6 di CLAUDE.md):
#     --strict-mcp-config senza --mcp-config = nessun server MCP, cosi' le
#     iterazioni non si portano dietro decine di tool inutili a questo progetto;
#     --effort letto a OGNI giro da STATE/effort.txt (default: medium). Un task
#     amministrativo non merita effort massimo; per i task di progettazione
#     (T7 encoding, T8 sharding, T10 gruppi transitivi) l'iterazione che chiude
#     quella precedente scrive "high" in STATE/effort.txt.
#     NON usare --bare per togliere gli hook: legge l'auth solo da
#     ANTHROPIC_API_KEY, mai OAuth/portachiavi ⇒ romperebbe ogni iterazione.
#  8. PAUSA ADATTIVA (2026-08-11): quando un job pesante gira sotto watchdog,
#     l'unico task legittimo e' sorvegliarlo, quindi un giro ogni 8 secondi e'
#     puro spreco — sono sessioni del modello spese per dire "il processo e'
#     ancora vivo". In quel caso si dorme SLEEP_WATCH (default 600 s) invece di
#     SLEEP_IDLE (default 8 s). Il run e il watchdog sono processi INDIPENDENTI
#     dal loop: rallentare la sorveglianza non rallenta il calcolo e non rischia
#     di perdere il verdetto, che resta nel log ad aspettare. Appena il watchdog
#     esce (job finito o killato) si torna da soli al ritmo veloce, cosi' i task
#     di seguito (drat-trim, FOUND.md, hash) non pagano l'attesa lunga.
#     Entrambi i valori sono sovrascrivibili da ambiente:
#       SLEEP_WATCH=300 MAX_ITER=400 bash scripts/loop.sh
#  9. IGIENE DELL'AMBIENTE (2026-08-11): se il loop viene lanciato da DENTRO una
#     sessione Claude Code (o da un altro agente) invece che da un Terminale pulito,
#     le variabili di sessione del padre verrebbero ereditate dalle sessioni figlie:
#     CLAUDE_EFFORT scavalcherebbe l'--effort letto da STATE/effort.txt (sorveglianza
#     amministrativa eseguita a effort massimo = spreco), e SSE_PORT / MESSAGING_SOCKET
#     / SESSION_ID punterebbero alla sessione sbagliata. Si ripuliscono qui, cosi' il
#     driver e' corretto da qualunque contesto venga lanciato. ANTHROPIC_* NON si tocca:
#     e' l'autenticazione.
set -o pipefail
cd "$(dirname "$0")/.." || exit 1

# NB: grep -oE, non `sed` con \| — il sed BSD di macOS non supporta l'alternanza
# nelle regex base e il comando restituirebbe una lista vuota, in silenzio.
for _v in $(env | grep -oE '^(CLAUDE_CODE_[A-Z_0-9]*|CLAUDECODE|CLAUDE_EFFORT|CLAUDE_PID|CLAUDE_PLUGIN_DATA|CODEX_[A-Z_0-9]*)'); do
  unset "$_v"
done
unset _v
mkdir -p results/logs
export PATH="$PWD/.venv/bin:$PATH"

MAX_ITER="${MAX_ITER:-200}"; FAILS=0; ITER=0
SLEEP_IDLE="${SLEEP_IDLE:-8}"       # c'e' lavoro da fare: si incalza
SLEEP_WATCH="${SLEEP_WATCH:-600}"   # job pesante sotto watchdog: si sorveglia e basta
LOG=results/logs/loop.log
PROMPT="Leggi CLAUDE.md e STATE/HANDOFF.md, poi esegui UNA sola iterazione del ciclo operativo e termina."
ALLOW="Bash Read Write Edit MultiEdit Glob Grep LS TodoWrite Task Agent BashOutput KillShell NotebookEdit"
DENY="Bash(sudo:*)"

echo "=== loop avviato $(date '+%F %T') · pid $$ · max $MAX_ITER iterazioni · pausa ${SLEEP_IDLE}s/${SLEEP_WATCH}s ===" | tee -a "$LOG"
while [ "$ITER" -lt "$MAX_ITER" ]; do
  ITER=$((ITER+1))
  STATUS=$(tr -d '[:space:]' < STATE/status.txt 2>/dev/null || echo RUN)
  [ "$STATUS" = "DONE" ]    && echo "Risultato raggiunto (vedi results/FOUND.md)." | tee -a "$LOG" && break
  [ "$STATUS" = "BLOCKED" ] && echo "Bloccato: serve l'umano (vedi STATE/HANDOFF.md)." | tee -a "$LOG" && break
  [ "$STATUS" = "PAUSE" ]   && echo "PAUSE richiesta: stop pulito, nulla perso." | tee -a "$LOG" && break

  EFFORT=$(tr -d '[:space:]' < STATE/effort.txt 2>/dev/null); EFFORT="${EFFORT:-medium}"
  echo "--- iterazione $ITER · $(date '+%F %T') · effort $EFFORT ---" | tee -a "$LOG"
  if caffeinate -i claude --model claude-fable-5 --permission-mode acceptEdits \
       --effort "$EFFORT" --strict-mcp-config \
       -p "$PROMPT" --disallowedTools "$DENY" --allowedTools $ALLOW 2>&1 | tee -a "$LOG"; then
    FAILS=0
  else
    FAILS=$((FAILS+1))
    echo "Fallimento $FAILS (limiti?)" | tee -a "$LOG"
    if [ "$FAILS" -ge 4 ]; then
      echo "Limiti/token probabilmente esauriti: stato salvo su disco, rilancia piu' tardi." | tee -a "$LOG"
      break
    fi
    sleep 300
  fi

  # Deviazione 8: pausa adattiva. Il pattern richiede un PID come primo argomento,
  # cosi' non fa falsi positivi su shell che citano "watchdog.sh" in una riga di comando.
  if pgrep -f 'scripts/watchdog\.sh [0-9]' > /dev/null 2>&1; then
    echo "    (job sotto watchdog: prossimo controllo fra ${SLEEP_WATCH}s)" | tee -a "$LOG"
    sleep "$SLEEP_WATCH"
  else
    sleep "$SLEEP_IDLE"
  fi
done
echo "=== loop terminato $(date '+%F %T') dopo $ITER iterazioni (status: $(tr -d '[:space:]' < STATE/status.txt 2>/dev/null)) ===" | tee -a "$LOG"
