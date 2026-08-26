#!/usr/bin/env bash
# uninstall.sh - Removes the PATH symlink and any installed cron jobs.
# Does NOT delete the project directory, config, history data, or generated
# reports/logs - remove those manually if you no longer need them.

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly SYMLINK_TARGET="/usr/local/bin/diskguardian"

[[ "$EUID" -eq 0 ]] || { echo "Run this uninstaller with sudo/root."; exit 1; }

if [[ -L "$SYMLINK_TARGET" ]]; then
    rm -f "$SYMLINK_TARGET"
    echo "Removed symlink $SYMLINK_TARGET"
fi

if [[ -x "$SCRIPT_DIR/cron/guardian_scheduler.sh" ]]; then
    "$SCRIPT_DIR/cron/guardian_scheduler.sh" remove
fi

echo "Guardian uninstalled. Project files remain at: $SCRIPT_DIR"
