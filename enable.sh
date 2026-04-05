#!/bin/bash
#
# Enable script for dbus-smartshunt-jk-bms
# May be run on boot via rc.local (see install-service.sh) or manually
#

#set -x

INSTALL_DIR="/data/apps/dbus-smartshunt-jk-bms"
SERVICE_NAME="dbus-smartshunt-jk-bms"

chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
chmod +x "$INSTALL_DIR"/*.py 2>/dev/null || true
chmod +x "$INSTALL_DIR"/service/run 2>/dev/null || true
chmod +x "$INSTALL_DIR"/service/log/run 2>/dev/null || true

if [ ! -f /data/rc.local ]; then
    echo "#!/bin/bash" > /data/rc.local
    chmod 755 /data/rc.local
fi

sed -i "/.*$SERVICE_NAME.*/d" /data/rc.local

RC_ENTRY="bash $INSTALL_DIR/enable.sh > $INSTALL_DIR/startup.log 2>&1 &"
echo "$RC_ENTRY" >> /data/rc.local

if [ -d "/service/$SERVICE_NAME" ]; then
    svc -d "/service/$SERVICE_NAME" 2>/dev/null || true
fi
sleep 1

pkill -f "supervise $SERVICE_NAME" 2>/dev/null || true
pkill -f "multilog .*dbus-smartshunt-jk-bms" 2>/dev/null || true
pkill -f "python.*dbus-smartshunt-jk-bms" 2>/dev/null || true

if [ -L "/service/$SERVICE_NAME" ]; then
    rm "/service/$SERVICE_NAME"
fi
ln -s "$INSTALL_DIR/service" "/service/$SERVICE_NAME"

echo "$SERVICE_NAME enabled"
