#!/usr/bin/env bash
# lsams_scheduler.sh - Installs or removes the periodic cron job that runs
# LSAMS unattended. Managed via a dedicated cron file in /etc/cron.d so it
# does not disturb the invoking user's personal crontab.
#
# Usage:
#   sudo cron/lsams_scheduler.sh install "0 3 * * *"   # daily at 03:00
#   sudo cron/lsams_scheduler.sh remove

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LSAMS_HOME="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
readonly CRON_FILE="/etc/cron.d/lsams"

usage() {
    echo "Usage: $0 install \"CRON_SCHEDULE\" | remove"
    echo "Example: $0 install \"0 3 * * *\"   # every day at 03:00"
    exit 1
}

[[ "$EUID" -eq 0 ]] || { echo "Must be run as root."; exit 1; }
[[ $# -ge 1 ]] || usage

case "$1" in
    install)
        schedule="${2:-0 3 * * *}"
        cat > "$CRON_FILE" <<EOF
# Managed by LSAMS (cron/lsams_scheduler.sh) - do not edit lines below by hand.
# Runs a full security audit and emails/Slack/Telegram-alerts on low scores.
${schedule} root ${LSAMS_HOME}/lsams.sh --full >> ${LSAMS_HOME}/logs/cron.log 2>&1
EOF
        chmod 644 "$CRON_FILE"
        echo "Installed cron job in $CRON_FILE with schedule: $schedule"
        ;;
    remove)
        if [[ -f "$CRON_FILE" ]]; then
            rm -f "$CRON_FILE"
            echo "Removed $CRON_FILE"
        else
            echo "No LSAMS cron job found at $CRON_FILE"
        fi
        ;;
    *)
        usage
        ;;
esac
