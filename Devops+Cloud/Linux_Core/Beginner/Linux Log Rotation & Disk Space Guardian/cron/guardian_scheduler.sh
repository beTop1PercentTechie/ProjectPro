#!/usr/bin/env bash
# guardian_scheduler.sh - Installs or removes the two cron jobs Guardian is
# designed around: a frequent lightweight monitor pass and a less-frequent
# full sweep. Managed via a dedicated cron file in /etc/cron.d so it does
# not disturb the invoking user's personal crontab.
#
# Usage:
#   sudo cron/guardian_scheduler.sh install ["*/5 * * * *"] ["0 3 * * *"]
#   sudo cron/guardian_scheduler.sh remove

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
GUARDIAN_HOME="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
readonly CRON_FILE="/etc/cron.d/diskguardian"

usage() {
    echo "Usage: $0 install [\"MONITOR_SCHEDULE\"] [\"FULL_SCHEDULE\"] | remove"
    echo "Example: $0 install \"*/5 * * * *\" \"0 3 * * *\""
    exit 1
}

[[ "$EUID" -eq 0 ]] || { echo "Must be run as root."; exit 1; }
[[ $# -ge 1 ]] || usage

case "$1" in
    install)
        monitor_schedule="${2:-*/5 * * * *}"
        full_schedule="${3:-0 3 * * *}"
        cat > "$CRON_FILE" <<EOF
# Managed by Guardian (cron/guardian_scheduler.sh) - do not edit lines below by hand.
# Frequent pass: real-time tracking + preemptive alerting only (cheap).
${monitor_schedule} root ${GUARDIAN_HOME}/guardian.sh --monitor >> ${GUARDIAN_HOME}/logs/cron.log 2>&1
# Full sweep: adds space-hog scanning (du/find) and log rotation (heavier).
${full_schedule} root ${GUARDIAN_HOME}/guardian.sh --full >> ${GUARDIAN_HOME}/logs/cron.log 2>&1
EOF
        chmod 644 "$CRON_FILE"
        echo "Installed cron jobs in $CRON_FILE"
        echo "  monitor: $monitor_schedule"
        echo "  full:    $full_schedule"
        ;;
    remove)
        if [[ -f "$CRON_FILE" ]]; then
            rm -f "$CRON_FILE"
            echo "Removed $CRON_FILE"
        else
            echo "No Guardian cron job found at $CRON_FILE"
        fi
        ;;
    *)
        usage
        ;;
esac
