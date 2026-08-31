#!/usr/bin/env bash
# backup-cron-scheduler.sh - Installs or removes the scheduled backup job.
# Managed via a dedicated file in /etc/cron.d so it does not disturb the
# invoking user's personal crontab.
#
# Usage:
#   sudo cron/backup-cron-scheduler.sh install "0 2 * * *"   # daily at 02:00
#   sudo cron/backup-cron-scheduler.sh remove

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BAT_HOME="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
readonly CRON_FILE="/etc/cron.d/backup-automation"

usage() {
    echo "Usage: $0 install \"CRON_SCHEDULE\" | remove"
    echo "Example: $0 install \"0 2 * * *\"   # every day at 02:00"
    exit 1
}

[[ "$EUID" -eq 0 ]] || { echo "Must be run as root."; exit 1; }
[[ $# -ge 1 ]] || usage

case "$1" in
    install)
        schedule="${2:-0 2 * * *}"
        cat > "$CRON_FILE" <<EOF
# Managed by the Backup Automation Tool (cron/backup-cron-scheduler.sh) -
# do not edit the line below by hand.
${schedule} root ${BAT_HOME}/bin/backup.sh --no-color >> ${BAT_HOME}/logs/cron.log 2>&1
EOF
        chmod 644 "$CRON_FILE"
        echo "Installed cron job in $CRON_FILE with schedule: $schedule"
        ;;
    remove)
        if [[ -f "$CRON_FILE" ]]; then
            rm -f "$CRON_FILE"
            echo "Removed $CRON_FILE"
        else
            echo "No backup cron job found at $CRON_FILE"
        fi
        ;;
    *)
        usage
        ;;
esac
