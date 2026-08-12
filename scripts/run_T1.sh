#!/bin/bash
# T1 — controlli obbligatori (vedi STATE/backlog.md). Output nei log, exit code riassuntivi.
cd "$(dirname "$0")/.." || exit 99
PY=.venv/bin/python3
"$PY" controls.py              > results/logs/T1_controls.log        2>&1; E1=$?
"$PY" sat_cyclic.py  controls  > results/logs/T1_cpsat_controls.log  2>&1; E2=$?
"$PY" sat2_cyclic.py controls  > results/logs/T1_pysat_controls.log  2>&1; E3=$?
"$PY" pb_adder.py              > results/logs/T1_pb_adder.log        2>&1; E4=$?
echo "exit codes: controls=$E1 cpsat=$E2 pysat=$E3 pb_adder=$E4"
[ $E1 -eq 0 ] && [ $E2 -eq 0 ] && [ $E3 -eq 0 ] && [ $E4 -eq 0 ]
