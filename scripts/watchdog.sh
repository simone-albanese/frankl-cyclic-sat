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
