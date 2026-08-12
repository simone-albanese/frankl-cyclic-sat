#!/bin/bash
# scripts/stato.sh — fotografia in 10 righe di "sta andando?".
# Sola lettura: non tocca nulla, si puo' lanciare quando si vuole.
#   bash ~/Documents/Matematics/frankl/scripts/stato.sh
cd "$(dirname "$0")/.." || exit 1

LOG=results/logs/T9b_cadical_z15.log
DRAT=results/z15min3.drat
VERDE=$'\033[32m'; ROSSO=$'\033[31m'; GIALLO=$'\033[33m'; GRIGIO=$'\033[90m'; FINE=$'\033[0m'

echo
echo "  ${GRIGIO}Progetto Frankl · $(date '+%H:%M:%S del %d %b')${FINE}"
echo "  ${GRIGIO}────────────────────────────────────────────${FINE}"

# --- il calcolo ---
PID=$(pgrep -f "cadical results/z15min3.cnf" | head -1)
if [ -n "$PID" ]; then
  read -r ET RSS <<< "$(ps -o etime=,rss= -p "$PID" | awk '{print $1, $2}')"
  printf "  calcolo Z15   ${VERDE}IN CORSO${FINE}  da %s  ·  RAM %.1f GB / 9\n" "$ET" "$(echo "$RSS/1048576" | bc -l)"
else
  echo "  calcolo Z15   ${GIALLO}NON in esecuzione${FINE}  (finito, o fermato dal watchdog)"
fi

# --- il verdetto: e' l'unica cosa che conta davvero ---
V=$(grep -m1 '^s ' "$LOG" 2>/dev/null)
if [ -n "$V" ]; then
  echo "  verdetto      ${VERDE}${V}${FINE}   <-- e' arrivato"
elif grep -q 'KILL' "$LOG" 2>/dev/null; then
  echo "  verdetto      ${ROSSO}nessuno: il watchdog ha fermato il run${FINE}"
else
  echo "  verdetto      ${GRIGIO}non ancora (normale)${FINE}"
fi

[ -f "$DRAT" ] && echo "  prova scritta $(ls -lh "$DRAT" | awk '{print $5}')  ${GRIGIO}(attesi 5-7 GB)${FINE}"
[ -f "$LOG" ]  && tail -n 1 "$LOG" | awk -v g="$GRIGIO" -v f="$FINE" '/^c [^ ]+ +[0-9]/ {printf "  conflitti     %s  %sa t=%ss%s\n", $9, g, $3, f}'

# --- chi sorveglia ---
# La scadenza si ricava dal watchdog stesso (avvio + cap in minuti), cosi' resta
# vera dopo ogni proroga invece di essere scritta a mano qui dentro.
WPID=$(pgrep -f 'scripts/watchdog\.sh [0-9]' | head -1)
if [ -n "$WPID" ]; then
  # 3o argomento DOPO watchdog.sh = i minuti di cap (dopo PID e tetto RAM).
  # Non usare una posizione fissa: cambia se il driver e' invocato come "bash" o "/bin/bash".
  WCAP=$(ps -o command= -p "$WPID" | awk '{for(i=1;i<=NF;i++) if($i ~ /watchdog\.sh$/) {print $(i+3); exit}}')
  WSTART=$(ps -o lstart= -p "$WPID")
  FINEW=$(python3 -c "
import datetime as dt,sys
s=dt.datetime.strptime(sys.argv[1].strip(),'%a %b %d %H:%M:%S %Y')
f=s+dt.timedelta(minutes=int(sys.argv[2]))
r=(f-dt.datetime.now()).total_seconds()/60
print(f\"{f:%H:%M} (fra {r:.0f} min)\" if r>0 else f\"{f:%H:%M} (scaduto)\")
" "$WSTART" "$WCAP" 2>/dev/null || echo "cap ${WCAP} min")
  echo "  watchdog      ${VERDE}attivo${FINE}   ${GRIGIO}(ferma tutto alle ${FINEW})${FINE}"
else
  echo "  watchdog      ${GRIGIO}assente${FINE}"
fi
pgrep -f "bash scripts/loop.sh" > /dev/null \
  && echo "  ciclo         ${VERDE}attivo${FINE}   ${GRIGIO}(controlla ogni 10 min)${FINE}" \
  || echo "  ciclo         ${GIALLO}fermo${FINE}    ${GRIGIO}-> bash scripts/loop.sh${FINE}"

# --- la corrente: senza, stanotte non si arriva ---
B=$(pmset -g batt | tail -1)
if pmset -g batt | grep -q "AC Power"; then
  echo "  corrente      ${VERDE}collegata${FINE}"
else
  echo "  corrente      ${ROSSO}A BATTERIA${FINE}  $(echo "$B" | grep -oE '[0-9]+%; [a-z]+; [0-9:]+ remaining' || echo "$B")"
  echo "                ${ROSSO}attacca il caricabatterie: serve fino alle 09:03${FINE}"
fi
echo
