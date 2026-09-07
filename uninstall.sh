#!/bin/bash
# Removes the CursorUIViewService watchdog.
# Usage: ./uninstall.sh [install_dir]
#   install_dir defaults to ~/scripts (must match what install.sh used)

INSTALL_DIR="${1:-$HOME/scripts}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LABEL="cursoruiviewservice-watchdog"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS_DIR/$LABEL.plist"
rm -f "$INSTALL_DIR/cursoruiviewservice-watchdog.sh"
rm -f "$INSTALL_DIR/cursoruiviewservice-watchdog.command"
rm -f "/tmp/$LABEL.log" "/tmp/$LABEL.state" "/tmp/$LABEL.sample.tmp"

echo "Uninstalled."
