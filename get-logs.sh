#!/bin/bash

# Show logs from dbus-smartshunt-jk-bms

LOG_DIR="/data/apps/dbus-smartshunt-jk-bms/service/log"

if [ -d "$LOG_DIR" ]; then
    echo "=== dbus-smartshunt-jk-bms logs ==="
    echo ""
    tail -n 100 "$LOG_DIR/current" 2>/dev/null | tai64nlocal 2>/dev/null || tail -n 100 "$LOG_DIR/current"
else
    echo "Log directory not found: $LOG_DIR"
    echo "Is the service installed?"
fi
