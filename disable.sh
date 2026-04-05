#!/bin/bash
#
# Disable script for dbus-smartshunt-jk-bms
# Cleanly stops and removes the service and its settings
#

#set -x

INSTALL_DIR="/data/apps/dbus-smartshunt-jk-bms"
SERVICE_NAME="dbus-smartshunt-jk-bms"

echo
echo "Disabling $SERVICE_NAME..."

rm -rf "/service/$SERVICE_NAME" 2>/dev/null || true

pkill -f "supervise $SERVICE_NAME" 2>/dev/null || true
pkill -f "multilog .* /var/log/$SERVICE_NAME" 2>/dev/null || true
pkill -f "python.*dbus-smartshunt-jk-bms" 2>/dev/null || true
pkill -f "python.*smartshunt" 2>/dev/null || true

sed -i "/.*$SERVICE_NAME.*/d" /data/rc.local 2>/dev/null || true

echo "Service stopped and rc.local cleaned"

echo "Cleaning up D-Bus settings..."

delete_setting() {
    local path="$1"
    dbus -y com.victronenergy.settings "$path" SetValue "" 2>/dev/null || true
}

for path in $(dbus -y com.victronenergy.settings / GetValue 2>/dev/null | grep -oE "Settings/Devices/smartshuntjk/[^']*" | sort -u); do
    echo "  Removing /$path"
    delete_setting "/$path"
done

for path in $(dbus -y com.victronenergy.settings / GetValue 2>/dev/null | grep -oE "Settings/Devices/smartshuntjk_HYBRID01/[^']*" | sort -u); do
    echo "  Removing /$path"
    delete_setting "/$path"
done

# Legacy paths from dbus-aggregate-smartshunts (optional cleanup)
for path in $(dbus -y com.victronenergy.settings / GetValue 2>/dev/null | grep -oE "Settings/Devices/aggregate_smartshunts/[^']*" | sort -u); do
    echo "  Removing /$path"
    delete_setting "/$path"
done

for path in $(dbus -y com.victronenergy.settings / GetValue 2>/dev/null | grep -oE "Settings/Devices/aggregateshunts/[^']*" | sort -u); do
    echo "  Removing /$path"
    delete_setting "/$path"
done

for path in $(dbus -y com.victronenergy.settings / GetValue 2>/dev/null | grep -oE "Settings/Devices/aggregateshunts_AGGREGATE01/[^']*" | sort -u); do
    echo "  Removing /$path"
    delete_setting "/$path"
done

echo
echo "$SERVICE_NAME disabled and settings cleaned"
echo
echo "Note: To completely remove, also delete: $INSTALL_DIR"
echo
