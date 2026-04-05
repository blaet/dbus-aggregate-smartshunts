#!/bin/bash
#
# Remote installer for dbus-smartshunt-jk-bms on Venus OS
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/blaet/dbus-aggregate-smartshunts/flavour/jk-bms-voltage/install.sh | bash
#
# Optional: REPO_URL, REPO_BRANCH (default branch for this flavour)

set -e

REPO_URL="${REPO_URL:-https://github.com/blaet/dbus-aggregate-smartshunts.git}"
REPO_BRANCH="${REPO_BRANCH:-flavour/jk-bms-voltage}"
INSTALL_DIR="/data/apps/dbus-smartshunt-jk-bms"
SERVICE_NAME="dbus-smartshunt-jk-bms"

echo "========================================"
echo "SmartShunt + JK BMS — installer"
echo "========================================"
echo ""

# Venus OS keeps user-writable data under /data (Cerbo, Venus GX, etc.).
# /data/apps is only a convention for third-party software—it is not always present until created.
if [ ! -d "/data" ]; then
    echo "Error: /data not found. This installer expects Victron Venus OS."
    exit 1
fi
mkdir -p /data/apps || {
    echo "Error: could not create /data/apps (check permissions / storage)."
    exit 1
}

echo "Step 1: Checking for git..."
if ! command -v git >/dev/null 2>&1; then
    echo "Git not found. Installing git..."
    if ! opkg install git; then
        echo "Error: Failed to install git."
        exit 1
    fi
    echo "✓ Git installed successfully"
else
    echo "✓ Git already installed"
fi
echo ""

echo "Step 2: Setting up repository..."
cd /data/apps

NEEDS_RESTART=false

if [ -d "$INSTALL_DIR" ]; then
    echo "Directory exists: $INSTALL_DIR"
    cd "$INSTALL_DIR"

    if [ -d .git ]; then
        echo "Already a git repository. Checking for updates (branch: $REPO_BRANCH)..."
        git fetch origin
        git checkout "$REPO_BRANCH" 2>/dev/null || git checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH"
        git branch --set-upstream-to="origin/$REPO_BRANCH" "$REPO_BRANCH" 2>/dev/null || true
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse "origin/$REPO_BRANCH")

        if [ "$LOCAL" != "$REMOTE" ]; then
            echo "Updates available. Pulling latest changes..."
            git pull
            NEEDS_RESTART=true
            echo "✓ Repository updated"
        else
            echo "✓ Already up to date"
        fi
    else
        echo "Not a git repository. Converting..."
        git init
        git config --global --add safe.directory "$INSTALL_DIR"
        git remote add origin "$REPO_URL"
        git fetch origin
        git checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH"
        git branch --set-upstream-to="origin/$REPO_BRANCH" "$REPO_BRANCH"
        NEEDS_RESTART=true
        echo "✓ Converted to git repository"
    fi
else
    echo "Cloning repository (branch: $REPO_BRANCH)..."
    git clone -b "$REPO_BRANCH" --single-branch "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    git config --global --add safe.directory "$INSTALL_DIR"
    NEEDS_RESTART=false
    echo "✓ Repository cloned"
fi
echo ""

echo "Step 3: Installing/updating service..."

if [ -L "/service/$SERVICE_NAME" ] && svstat "/service/$SERVICE_NAME" 2>/dev/null | grep -q "up"; then
    if [ "$NEEDS_RESTART" = true ]; then
        echo "Service running; restarting after update..."
        svc -t "/service/$SERVICE_NAME"
        sleep 2
        if svstat "/service/$SERVICE_NAME" 2>/dev/null | grep -q "up"; then
            echo "✓ Service restarted successfully"
        else
            echo "Warning: Check logs: tail -f $INSTALL_DIR/service/log/current"
        fi
    else
        echo "✓ No updates needed"
    fi
else
    echo "Running install-service.sh..."
    bash "$INSTALL_DIR/install-service.sh"
fi
echo ""

echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "Service status:"
svstat "/service/$SERVICE_NAME" 2>/dev/null || echo "(not linked yet)"
echo ""
echo "View logs:"
echo "  tail -f $INSTALL_DIR/service/log/current"
echo ""
echo "Service management:"
echo "  svc -u /service/$SERVICE_NAME  # Start"
echo "  svc -d /service/$SERVICE_NAME  # Stop"
echo "  svc -t /service/$SERVICE_NAME  # Restart"
echo ""
