#!/bin/bash
# Launch the CursorUIViewService watchdog — process will appear as
# "cursoruiviewservice-watchdog" in Login Items / Activity Monitor
# instead of "bash".
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec -a "cursoruiviewservice-watchdog" /bin/bash "$SCRIPT_DIR/cursoruiviewservice-watchdog.sh"
