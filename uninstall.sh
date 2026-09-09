#!/bin/bash
# Removes the CursorUIViewService watchdog.
# Usage: ./uninstall.sh [install_dir]
#   install_dir defaults to ~/scripts (must match what install.sh used)

INSTALL_DIR="${1:-$HOME/scripts}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LABEL="com.github.tollfree.cursoruiviewservice-watchdog"
SHORT_NAME="cursoruiviewservice-watchdog"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$LABEL.plist"
rm -f "$INSTALL_DIR/cursoruiviewservice-watchdog.sh"
rm -f "$INSTALL_DIR/cursoruiviewservice-watchdog.command"
rm -f "/tmp/$SHORT_NAME.log" "/tmp/$SHORT_NAME.state" "/tmp/$SHORT_NAME.sample.tmp"

echo "Uninstalled."
