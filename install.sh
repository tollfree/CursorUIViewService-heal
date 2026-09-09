#!/bin/bash
# Installs the CursorUIViewService watchdog.
# Usage: ./install.sh [install_dir]
#   install_dir defaults to ~/scripts

set -e

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${1:-$HOME/scripts}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LABEL="com.github.tollfree.cursoruiviewservice-watchdog"
SHORT_NAME="cursoruiviewservice-watchdog"

case "$INSTALL_DIR" in
  *"Mobile Documents"*|*iCloud*)
    echo "Error: $INSTALL_DIR looks like an iCloud Drive path."
    echo "launchd cannot execute files there (macOS TCC blocks background"
    echo "processes from accessing the iCloud container). Pick a plain"
    echo "local folder instead, e.g.: ./install.sh ~/scripts"
    exit 1
    ;;
esac

mkdir -p "$INSTALL_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

cp "$SRC_DIR/cursoruiviewservice-watchdog.sh" "$INSTALL_DIR/"
cp "$SRC_DIR/cursoruiviewservice-watchdog.command" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/cursoruiviewservice-watchdog.sh"
chmod +x "$INSTALL_DIR/cursoruiviewservice-watchdog.command"

sed "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
  "$SRC_DIR/com.github.tollfree.cursoruiviewservice-watchdog.plist.template" \
  > "$LAUNCH_AGENTS_DIR/$LABEL.plist"

plutil -lint "$LAUNCH_AGENTS_DIR/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENTS_DIR/$LABEL.plist"

echo
echo "Installed to: $INSTALL_DIR"
echo "LaunchAgent:  $LAUNCH_AGENTS_DIR/$LABEL.plist"
echo "Log:          /tmp/$SHORT_NAME.log"
echo
echo "Check status: launchctl print gui/$(id -u)/$LABEL"
echo "Tail log:     tail -f /tmp/$SHORT_NAME.log"
