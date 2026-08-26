#!/bin/bash
# Gracefully stop the Omarchy VM (ACPI powerdown, then force after 60s).
set -uo pipefail
DIR="$HOME/omarchy-vm"
PIDFILE="$DIR/qemu.pid"

[ -f "$PIDFILE" ] || { echo "not running"; exit 0; }
PID=$(cat "$PIDFILE")
kill -0 "$PID" 2>/dev/null || { echo "not running"; rm -f "$PIDFILE"; exit 0; }

python3 "$DIR/qmp.py" "$DIR/qmp.sock" system_powerdown >/dev/null 2>&1
for _ in $(seq 1 30); do
  kill -0 "$PID" 2>/dev/null || { echo "stopped"; rm -f "$PIDFILE"; exit 0; }
  sleep 2
done
echo "guest ignored powerdown; killing pid $PID"
kill "$PID" && rm -f "$PIDFILE"
