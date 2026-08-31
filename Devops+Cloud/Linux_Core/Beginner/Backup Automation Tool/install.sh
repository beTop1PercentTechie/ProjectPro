#!/usr/bin/env bash
# install.sh - Prepares the Backup Automation Tool for use in place:
# creates backups/logs/reports directories, sets executable permissions,
# and optionally symlinks the bin/ scripts onto PATH.
#
# Usage: sudo ./install.sh [--symlink]

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

[[ "$EUID" -eq 0 ]] || { echo "Run this installer with sudo/root."; exit 1; }

echo "Installing Backup Automation Tool from: $SCRIPT_DIR"

mkdir -p "$SCRIPT_DIR/backups" "$SCRIPT_DIR/logs" "$SCRIPT_DIR/reports" "$SCRIPT_DIR/restore-test"

find "$SCRIPT_DIR" -maxdepth 1 -name '*.sh' -exec chmod +x {} \;
find "$SCRIPT_DIR/bin" "$SCRIPT_DIR/lib" "$SCRIPT_DIR/cron" "$SCRIPT_DIR/tests" \
    -name '*.sh' -exec chmod +x {} \;

echo "Set executable permissions on all scripts."

if [[ "${1:-}" == "--symlink" ]]; then
    ln -sf "$SCRIPT_DIR/bin/backup.sh" /usr/local/bin/bat-backup
    ln -sf "$SCRIPT_DIR/bin/restore.sh" /usr/local/bin/bat-restore
    ln -sf "$SCRIPT_DIR/bin/list-backups.sh" /usr/local/bin/bat-list
    ln -sf "$SCRIPT_DIR/bin/backup-status.sh" /usr/local/bin/bat-status
    echo "Symlinked: bat-backup, bat-restore, bat-list, bat-status -> /usr/local/bin"
    echo "You can now run 'bat-backup --help' from anywhere."
fi

cat <<DONE

Installation complete.

Next steps:
  1. Review config/backup.conf - especially SOURCE_DIRS
  2. Preview a run without touching anything:
       sudo $SCRIPT_DIR/bin/backup.sh --dry-run
  3. Run a real backup:
       sudo $SCRIPT_DIR/bin/backup.sh
  4. Check status and list backups:
       sudo $SCRIPT_DIR/bin/backup-status.sh
       sudo $SCRIPT_DIR/bin/list-backups.sh
  5. Schedule automatic backups:
       sudo $SCRIPT_DIR/cron/backup-cron-scheduler.sh install "0 2 * * *"

See README.md and docs/ for full documentation.
DONE
