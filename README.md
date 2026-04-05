# dbus-smartshunt-jk-bms

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

## Git branch

The **SmartShunt + JK BMS** behaviour lives on branch **`flavour/jk-bms-voltage`**. Use that branch for installs and updates (`install.sh` defaults to it). Other branches may carry different product flavours.

## Migrating from `dbus-aggregate-smartshunts`

If you used the old service name and install path:

1. Run the old project’s `disable.sh` (or remove `/service/dbus-aggregate-smartshunts` and the old `rc.local` line).
2. Clone this repo to `/data/apps/dbus-smartshunt-jk-bms`, check out **`flavour/jk-bms-voltage`**, and run `install-service.sh`.
3. Copy `config.ini` from the old directory if you had custom settings.
4. The D-Bus service name is now `com.victronenergy.battery.smartshunt_jk`; GUI device settings use new paths under `smartshuntjk_*`.

## Installation

### Prerequisites

- Victron Cerbo GX or Venus GX running Venus OS
- Exactly one Victron SmartShunt and a JK BMS visible on D-Bus (`com.victronenergy.battery.*`)
- SSH access to your Venus device

The installer expects a writable **`/data`** tree (normal on Venus). It creates **`/data/apps`** if it does not exist; Venus does not ship that folder by default, and older docs assumed it was already there after another app had created it.

### Recommended: One-Line Remote Install

```bash
ssh root@<cerbo-ip> "curl -fsSL https://raw.githubusercontent.com/blaet/dbus-aggregate-smartshunts/flavour/jk-bms-voltage/install.sh | bash"
```

This will:
- Install `git` if needed
- Clone or update the repository on branch **`flavour/jk-bms-voltage`**
- Install and start the service
- Survive reboots automatically

To use another branch, export variables for the shell running the script, e.g. `curl ... | REPO_BRANCH=main bash`.

### Manual Installation

If you prefer to install manually:

1. **SSH to your Venus device:**
   ```bash
   ssh root@cerbo
   ```

2. **Clone the repository** (directory name matches the Venus install path; branch **`flavour/jk-bms-voltage`**):
   ```bash
   cd /data/apps
   git clone -b flavour/jk-bms-voltage --single-branch https://github.com/blaet/dbus-aggregate-smartshunts.git dbus-smartshunt-jk-bms
   cd dbus-smartshunt-jk-bms
   ```
   SSH: `git clone -b flavour/jk-bms-voltage --single-branch git@github.com:blaet/dbus-aggregate-smartshunts.git dbus-smartshunt-jk-bms`

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
- Device name: "SmartShunt + JK BMS" (editable in UI)
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
   DEVICE_NAME = SmartShunt + JK BMS
   
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

1. **Discovery switch**: Navigate to **Settings → Switches** and find "* SmartShunt + JK"
   - **ON** (default): Creates or restores the shunt toggle in the UI when discovery runs
   - **OFF**: Hides shunt-related switches (monitoring continues for enabled shunt)

2. **Shunt switch**: The SmartShunt has a toggle switch
   - **ON** (default): Shunt feeds the virtual monitor
   - **OFF**: Shunt is excluded (virtual battery may show stale or empty data)

3. **Temperature Threshold Switches**: Two dimmable slider controls for smart temperature reporting
   - **Cold Limit**: Default 50°F (10°C) - adjustable from -58°F to 212°F (-50°C to 100°C)
     - Below this threshold, the aggregate reports the lowest shunt temperature
     - Reset to default by toggling the switch off and back on
   - **Hot Limit**: Default 105°F (40.5°C) - adjustable from -58°F to 212°F (-50°C to 100°C)
     - Above this threshold, the aggregate reports the highest shunt temperature
     - Reset to default by toggling the switch off and back on
   - Between thresholds, the aggregate reports the average temperature
   - The switch label shows the current setting in both Celsius and Fahrenheit

4. **Hiding switches**: When you're done configuring, turn off "* SmartShunt + JK" to hide shunt switches from the main UI. They may remain under device settings if you need them later.

**Example use cases:**
- Temporarily disable the shunt from the virtual monitor for testing
- Adjust temperature thresholds for LiFePO4 vs lead-acid

## Managing the Service

**View logs:**
```bash
/data/apps/dbus-smartshunt-jk-bms/get-logs.sh
```

**Restart after config changes:**
```bash
/data/apps/dbus-smartshunt-jk-bms/restart.sh
```

**Disable service:**
```bash
/data/apps/dbus-smartshunt-jk-bms/disable.sh
```

**Re-enable service:**
```bash
/data/apps/dbus-smartshunt-jk-bms/enable.sh
```

**Uninstall:**
```bash
/data/apps/dbus-smartshunt-jk-bms/uninstall.sh
```

## Monitoring

**Check the virtual battery service:**
```bash
dbus -y com.victronenergy.battery.smartshunt_jk / GetItems
```

**View real-time status:**
```bash
watch -n 1 'dbus -y com.victronenergy.battery.smartshunt_jk /Dc/0/Voltage GetValue && \
            dbus -y com.victronenergy.battery.smartshunt_jk /Dc/0/Current GetValue && \
            dbus -y com.victronenergy.battery.smartshunt_jk /Soc GetValue'
```

**Check logs in real-time:**
```bash
tail -f /data/apps/dbus-smartshunt-jk-bms/service/log/current | tai64nlocal
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

### Installer says `/data` not found

Run the install **on the Cerbo** (e.g. `ssh root@<cerbo-ip>` then paste the `curl … | bash` command). If you run `install.sh` on your laptop, `/data` will not exist and the script will correctly refuse to continue.

### Service won't start

**Check logs:**
```bash
tail -n 50 /data/apps/dbus-smartshunt-jk-bms/service/log/current | tai64nlocal
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

**D-Bus Service:** `com.victronenergy.battery.smartshunt_jk`

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
- `/History/*` - From the SmartShunt
- `/Alarms/*` - Passed through from physical shunts

## Credits

This project is **derived from** [dbus-aggregate-batteries](https://github.com/Dr-Gigavolt/dbus-aggregate-batteries) by **Dr-Gigavolt (Anton Labanc PhD)**.

### Original Work by Anton Labanc PhD

The foundational architecture and many core components come from the original dbus-aggregate-batteries project:
- D-Bus service architecture and monitoring patterns
- Configuration management system
- Service management scripts (install, enable, disable, restart, uninstall)
- Core aggregation logic and algorithms

### Modifications (SmartShunt + JK BMS)

Adapted and extended by Clinton Goudie-Nice for SmartShunt-centric monitoring:
- Reactive updates (event-driven instead of polling)
- Single SmartShunt with JK BMS pack voltage on the virtual battery service
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

For issues, questions, or contributions, see [github.com/blaet/dbus-aggregate-smartshunts](https://github.com/blaet/dbus-aggregate-smartshunts).
