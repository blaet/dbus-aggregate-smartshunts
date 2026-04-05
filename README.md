# dbus-aggregate-smartshunts

A Victron Venus OS service that exposes a **single virtual SmartShunt** on D-Bus using **one** Victron SmartShunt for current, SoC, alarms, history, and other monitor paths, while taking **pack voltage** from a **JK BMS** service (typical `dbus-serialbattery` / similar driver on Venus).

> **Note:** This project is derived from [dbus-aggregate-batteries](https://github.com/Dr-Gigavolt/dbus-aggregate-batteries) by Anton Labanc PhD and adapted for SmartShunt-centric monitoring.

## Purpose

Use one SmartShunt for accurate coulomb counting and monitoring, but show **cell-side pack voltage** from the JK BMS on the same virtual battery the rest of the system sees. The Cerbo then gets one consolidated battery device instead of juggling separate shunt and BMS monitors for the same bank.

**Requirements:**
- Exactly **one** Victron SmartShunt on D-Bus (`ProductId` `0xA389`)
- Exactly **one** JK BMS battery service, auto-detected by `ProductName` containing `JK` (case-insensitive), or set explicitly in `config.ini` (`JK_BMS_DBUS_SERVICE`)

**Key Benefits:**
- 🎯 **One virtual monitor** - Single battery entry for GUI and VRM-style consumers
- 📊 **SoC and Ah from the SmartShunt** - Same source as VictronConnect tuning
- 🔋 **Voltage from the BMS** - Pack voltage as reported by the JK path
- ⚡ **Reactive updates** - Refreshes when the shunt or JK voltage changes
- 🔧 **Capacity from the shunt** - Read from VE.Direct configuration (register `0x1000`)

## Features

- ✅ **Single SmartShunt** discovery by product ID `0xA389` (errors if zero or more than one)
- ✅ **JK BMS voltage** on `/Dc/0/Voltage` (auto-detect or config override)
- ✅ **All other primary paths** from the SmartShunt (current, SoC, consumed Ah, temperature, TTG, alarms, history, VE.Direct counters)
- ✅ **Power** derived as `voltage × current` when both are available (matches BMS voltage with shunt current)
- ✅ **Reactive updates** (event-driven via `DbusMonitor`)
- ✅ **Smart temperature reporting** from the shunt (threshold-based min/max/average logic)
- ✅ **Exponential backoff** for device discovery

## Installation

### Prerequisites

- Victron Cerbo GX or Venus GX running Venus OS
- Exactly one Victron SmartShunt and a JK BMS visible on D-Bus (`com.victronenergy.battery.*`)
- SSH access to your Venus device

### Recommended: One-Line Remote Install

```bash
ssh root@<cerbo-ip> "curl -fsSL https://raw.githubusercontent.com/TechBlueprints/dbus-aggregate-smartshunts/main/install.sh | bash"
```

This will:
- Install `git` if needed
- Clone or update the repository
- Install and start the service
- Survive reboots automatically

### Manual Installation

If you prefer to install manually:

1. **SSH to your Venus device:**
   ```bash
   ssh root@cerbo
   ```

2. **Clone the repository:**
   ```bash
   cd /data/apps
   git clone https://github.com/TechBlueprints/dbus-aggregate-smartshunts.git
   cd dbus-aggregate-smartshunts
   ```

3. **Run the service installer:**
   ```bash
   bash install-service.sh
   ```

That's it! The service will:
- Discover the single SmartShunt and resolve the JK BMS for voltage
- Read total capacity from that SmartShunt’s configuration
- Publish the virtual battery and persist across reboots

### Optional Configuration

**No config file is required!** The service runs with sensible defaults:
- Device name: "SmartShunts" (editable in UI)
- Temperature thresholds: Configurable via UI switches (see below)
- SmartShunt selection: Managed via UI switches (see below)

**Advanced users only:** If you need to customize operational settings (logging, polling intervals, error handling), you can create a `config.ini` file:

1. **Create your config:**
   ```bash
   cp config.default.ini config.ini
   nano config.ini
   ```

2. **Optional settings:**
   ```ini
   [DEFAULT]
   
   # Device name (also editable in UI)
   DEVICE_NAME = SmartShunts
   
   # If more than one battery service matches "JK" in ProductName, set the full D-Bus name:
   # JK_BMS_DBUS_SERVICE = com.victronenergy.battery.ttyUSB0
   
   # Logging level for troubleshooting
   LOGGING = INFO  # Options: ERROR, WARNING, INFO, DEBUG
   
   # Advanced operational settings (rarely need changing)
   UPDATE_INTERVAL_FIND_DEVICES = 1
   MAX_UPDATE_INTERVAL_FIND_DEVICES = 1800
   LOG_PERIOD = 300
   ```

3. **Restart the service:**
   ```bash
   ./restart.sh
   ```

### Finding SmartShunt Information

**List all battery services:**
```bash
dbus -y | grep battery
```

**Check a specific SmartShunt:**
```bash
dbus -y com.victronenergy.battery.ttyS5 /DeviceInstance GetValue
dbus -y com.victronenergy.battery.ttyS5 /CustomName GetValue
dbus -y com.victronenergy.battery.ttyS5 /Soc GetValue
```

## How It Works

1. **Discovery**: Finds exactly one SmartShunt (`0xA389`) and resolves the JK BMS (ProductName contains `JK`, or `JK_BMS_DBUS_SERVICE`). Discovery interval backs off when stable.
2. **UI Switches**: The SmartShunt can still be toggled via Settings → Switches like before.
3. **Reactive monitoring**: `DbusMonitor` callbacks on the SmartShunt paths and on `/Dc/0/Voltage` for the JK service.
4. **Publish**: Writes the virtual service: **voltage** from JK, **current / SoC / history / alarms / …** from the SmartShunt; **power** ≈ `V_jk × I_shunt` when both are valid.

## Configuration Reference

See `config.default.ini` for documentation of all settings.

**All settings have defaults - config file is optional!**

The config file is only needed for advanced operational settings like logging levels, polling intervals, and error handling timeouts. All functional settings (device name, temperature thresholds, SmartShunt selection) are managed via the UI.

## Managing SmartShunts via UI Switches

All SmartShunt discovery and control is now managed via the Venus OS UI:

1. **Discovery Switch**: Navigate to **Settings -> Switches** and find "* SmartShunt Discovery"
   - **ON** (default): Service scans for new SmartShunts and creates switches for them
   - **OFF**: Stops scanning, hides all switches (but continues aggregating enabled shunts)

2. **Shunt switch**: The SmartShunt has a toggle switch
   - **ON** (default): Shunt feeds the virtual monitor
   - **OFF**: Shunt is excluded (aggregate may show stale or empty data)

3. **Temperature Threshold Switches**: Two dimmable slider controls for smart temperature reporting
   - **Cold Limit**: Default 50°F (10°C) - adjustable from -58°F to 212°F (-50°C to 100°C)
     - Below this threshold, the aggregate reports the lowest shunt temperature
     - Reset to default by toggling the switch off and back on
   - **Hot Limit**: Default 105°F (40.5°C) - adjustable from -58°F to 212°F (-50°C to 100°C)
     - Above this threshold, the aggregate reports the highest shunt temperature
     - Reset to default by toggling the switch off and back on
   - Between thresholds, the aggregate reports the average temperature
   - The switch label shows the current setting in both Celsius and Fahrenheit

4. **Hiding Switches**: When you're done configuring, turn off "SmartShunt Discovery" to hide all switches from the main UI. They remain accessible in the device settings if you need to change them later.

**Example use cases:**
- Temporarily disable the shunt from the virtual monitor for testing
- Adjust temperature thresholds for LiFePO4 vs lead-acid

## Managing the Service

**View logs:**
```bash
/data/apps/dbus-aggregate-smartshunts/get-logs.sh
```

**Restart after config changes:**
```bash
/data/apps/dbus-aggregate-smartshunts/restart.sh
```

**Disable service:**
```bash
/data/apps/dbus-aggregate-smartshunts/disable.sh
```

**Re-enable service:**
```bash
/data/apps/dbus-aggregate-smartshunts/enable.sh
```

**Uninstall:**
```bash
/data/apps/dbus-aggregate-smartshunts/uninstall.sh
```

## Monitoring

**Check the virtual battery service:**
```bash
dbus -y com.victronenergy.battery.aggregateshunts / GetItems
```

**View real-time status:**
```bash
watch -n 1 'dbus -y com.victronenergy.battery.aggregateshunts /Dc/0/Voltage GetValue && \
            dbus -y com.victronenergy.battery.aggregateshunts /Dc/0/Current GetValue && \
            dbus -y com.victronenergy.battery.aggregateshunts /Soc GetValue'
```

**Check logs in real-time:**
```bash
tail -f /data/apps/dbus-aggregate-smartshunts/service/log/current | tai64nlocal
```

## Example setup

**System:**
- One bank with a JK BMS on serial/USB (D-Bus battery service whose name or `ProductName` indicates JK)
- One Victron SmartShunt on the same bank

**Configuration:**
```ini
# Usually no config.ini needed: JK BMS is found via ProductName containing "JK"
# If several JK-like services exist:
# JK_BMS_DBUS_SERVICE = com.victronenergy.battery.ttyUSB0
```

**Result:**
- Virtual monitor capacity matches the SmartShunt’s configured Ah
- `/Dc/0/Voltage` follows the JK BMS; current, SoC, and history follow the SmartShunt

## Troubleshooting

### Service won't start

**Check logs:**
```bash
tail -n 50 /data/apps/dbus-aggregate-smartshunts/service/log/current | tai64nlocal
```

**Common issues:**
- **Python errors**: Check syntax if you edited the code
- **Permission errors**: Ensure scripts are executable (`chmod +x *.sh`)

### SmartShunt or JK BMS not found

**List battery services:**
```bash
dbus -y | grep com.victronenergy.battery
```

**SmartShunt** must report `ProductId` `0xA389`. **JK BMS** must be uniquely identifiable (ProductName contains `JK`, or set `JK_BMS_DBUS_SERVICE`).

### Capacity auto-detection not working

**Requirements for capacity read:**
- SmartShunt must expose VE.Direct configuration (capacity in register `0x1000` via VictronConnect)

### SoC seems incorrect

**Check the physical SmartShunt:**
```bash
dbus -y com.victronenergy.battery.<your_shunt> /Soc GetValue
```

If the shunt SoC is wrong, calibrate it in VictronConnect:
- Sync to 100% when batteries are full
- Ensure capacity is configured correctly

## Technical Details

**D-Bus Service:** `com.victronenergy.battery.aggregateshunts`

**Product ID:** `0xA389` (41865) - SmartShunt (mirrored on the virtual service)

**Key D-Bus Paths:**
- `/Dc/0/Voltage` - Pack voltage (V) from **JK BMS**
- `/Dc/0/Current` - Current (A, positive = charging)
- `/Dc/0/Power` - Power (W)
- `/Dc/0/Temperature` - Temperature (°C)
- `/Soc` - State of charge (%)
- `/Capacity` - Remaining capacity (Ah)
- `/InstalledCapacity` - Total capacity (Ah)
- `/ConsumedAmphours` - Energy consumed (Ah)
- `/TimeToGo` - Time remaining (seconds)
- `/History/*` - Aggregated history data
- `/Alarms/*` - Passed through from physical shunts

## Credits

This project is **derived from** [dbus-aggregate-batteries](https://github.com/Dr-Gigavolt/dbus-aggregate-batteries) by **Dr-Gigavolt (Anton Labanc PhD)**.

### Original Work by Anton Labanc PhD

The foundational architecture and many core components come from the original dbus-aggregate-batteries project:
- D-Bus service architecture and monitoring patterns
- Configuration management system
- Service management scripts (install, enable, disable, restart, uninstall)
- Core aggregation logic and algorithms

### Modifications for SmartShunt Aggregation

Adapted and extended by Clinton Goudie-Nice for SmartShunt-specific use:
- Reactive updates (event-driven instead of polling)
- Auto-detection of SmartShunt capacity and single-shunt + JK BMS voltage sourcing
- Smart temperature logic from the shunt
- Stateless operation (all data derived from physical devices)
- Exponential backoff for device discovery

**Thanks to Anton Labanc PhD for creating the original dbus-aggregate-batteries project and sharing it under the MIT license, making this derivative work easy!**

## License

MIT License - See LICENSE file for full text

**Copyright (c) 2025 Clinton Goudie-Nice**  
**Copyright (c) 2022 Anton Labanc PhD**

This software is derived from dbus-aggregate-batteries by Anton Labanc PhD.
Portions of the original work (D-Bus architecture, configuration management, 
service scripts, and core aggregation logic) are retained and modified.

## Support

For issues, questions, or contributions, please open an issue on GitHub.
