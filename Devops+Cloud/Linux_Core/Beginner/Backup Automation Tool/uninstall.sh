#!/usr/bin/env bash
# uninstall.sh - Removes the PATH symlinks and any installed cron job.
# Does NOT delete the project directory, config, or existing backups/logs/
# reports - remove those manually if you no longer need them.

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

[[ "$EUID" -eq 0 ]] || { echo "Run this uninstaller with sudo/root."; exit 1; }

for name in bat-backup bat-restore bat-list bat-status; do
    if [[ -L "/usr/local/bin/$name" ]]; then
        rm -f "/usr/local/bin/$name"
        echo "Removed symlink /usr/local/bin/$name"
    fi
done

if [[ -x "$SCRIPT_DIR/cron/backup-cron-scheduler.sh" ]]; then
    "$SCRIPT_DIR/cron/backup-cron-scheduler.sh" remove
fi

echo "Backup Automation Tool uninstalled. Project files remain at: $SCRIPT_DIR"
echo "Your existing backups in $SCRIPT_DIR/backups were NOT deleted."
