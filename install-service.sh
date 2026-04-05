#!/bin/bash

# dbus-smartshunt-jk-bms installation script for Venus OS
# Installs to /data/apps/dbus-smartshunt-jk-bms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/data/apps/dbus-smartshunt-jk-bms"
SERVICE_TEMPLATE="/opt/victronenergy/service-templates/dbus-smartshunt-jk-bms"

echo "=== dbus-smartshunt-jk-bms Installation ==="
echo ""

if [ ! -d "/data/apps" ]; then
    echo "Error: /data/apps directory not found."
    echo "This script is designed for Venus OS."
    exit 1
fi

echo "Installing to: $INSTALL_DIR"

mkdir -p "$INSTALL_DIR"

echo "Copying files..."
cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"

chmod +x "$INSTALL_DIR/dbus-smartshunt-jk-bms.py"
chmod +x "$INSTALL_DIR"/*.sh
chmod +x "$INSTALL_DIR/service/run"
chmod +x "$INSTALL_DIR/service/log/run"

echo "Creating service template for autostart..."
mkdir -p "$SERVICE_TEMPLATE"
ln -sf "$INSTALL_DIR/service/run" "$SERVICE_TEMPLATE/run"
ln -sf "$INSTALL_DIR/service/log" "$SERVICE_TEMPLATE/log"

RC_LOCAL="/data/rc.local"
RC_ENTRY="ln -sf $INSTALL_DIR/service /service/dbus-smartshunt-jk-bms"

if [ ! -f "$RC_LOCAL" ]; then
    echo "#!/bin/bash" > "$RC_LOCAL"
    chmod +x "$RC_LOCAL"
fi

if ! grep -qF "$RC_ENTRY" "$RC_LOCAL"; then
    echo "Adding to rc.local for autostart..."
    echo "$RC_ENTRY" >> "$RC_LOCAL"
fi

echo "Creating service symlink..."
ln -sf "$INSTALL_DIR/service" /service/dbus-smartshunt-jk-bms

if [ ! -f "$INSTALL_DIR/config.ini" ]; then
    echo ""
    echo "Warning: config.ini not found!"
    echo "Please create $INSTALL_DIR/config.ini with your settings."
    echo "You can copy config.default.ini as a starting point:"
    echo "  cp $INSTALL_DIR/config.default.ini $INSTALL_DIR/config.ini"
    echo ""
fi

echo ""
echo "Installation complete!"
echo ""
echo "Service template created at: $SERVICE_TEMPLATE"
echo "The service will start automatically within a few seconds."
echo ""
echo "Service management commands:"
echo "  svc -u /service/dbus-smartshunt-jk-bms  # Start service"
echo "  svc -d /service/dbus-smartshunt-jk-bms  # Stop service"
echo "  svc -t /service/dbus-smartshunt-jk-bms  # Restart service"
echo "  svstat /service/dbus-smartshunt-jk-bms  # Check status"
echo ""
echo "View logs:"
echo "  tail -f $INSTALL_DIR/service/log/current"
echo ""
