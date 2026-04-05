#!/bin/bash

# Uninstall dbus-smartshunt-jk-bms

SERVICE_LINK="/service/dbus-smartshunt-jk-bms"
INSTALL_DIR="/data/apps/dbus-smartshunt-jk-bms"

echo "=== Uninstalling dbus-smartshunt-jk-bms ==="
echo ""
echo "This will:"
echo "  1. Stop and disable the service"
echo "  2. Remove $INSTALL_DIR"
echo "  3. Remove the Venus service template symlink"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Uninstall cancelled."
    exit 0
fi

if [ -L "$SERVICE_LINK" ]; then
    echo "Stopping service..."
    svc -d "$SERVICE_LINK" 2>/dev/null || true
    sleep 2
    echo "Removing service link..."
    rm -f "$SERVICE_LINK"
fi

sed -i '/dbus-smartshunt-jk-bms/d' /data/rc.local 2>/dev/null || true

rm -f "/opt/victronenergy/service-templates/dbus-smartshunt-jk-bms/run" 2>/dev/null || true
rm -f "/opt/victronenergy/service-templates/dbus-smartshunt-jk-bms/log" 2>/dev/null || true
rmdir "/opt/victronenergy/service-templates/dbus-smartshunt-jk-bms" 2>/dev/null || true

if [ -d "$INSTALL_DIR" ]; then
    echo "Removing installation directory..."
    rm -rf "$INSTALL_DIR"
fi

echo ""
echo "Uninstall complete!"
echo ""
