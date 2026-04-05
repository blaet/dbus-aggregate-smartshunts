#!/bin/bash

# Restart dbus-smartshunt-jk-bms service

SERVICE_LINK="/service/dbus-smartshunt-jk-bms"

echo "=== Restarting dbus-smartshunt-jk-bms ==="

if [ ! -L "$SERVICE_LINK" ]; then
    echo "Error: Service not installed at $SERVICE_LINK"
    echo "Run install-service.sh first"
    exit 1
fi

echo "Restarting service..."
svc -t "$SERVICE_LINK"

sleep 2

if svstat "$SERVICE_LINK" 2>/dev/null | grep -q "up"; then
    echo "✓ Service restarted successfully"
else
    echo "Warning: Service may not be running. Check status:"
    svstat "$SERVICE_LINK"
fi

echo ""
echo "View logs:"
echo "  tail -f /data/apps/dbus-smartshunt-jk-bms/service/log/current"
echo ""
