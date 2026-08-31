#!/usr/bin/env bash
# backup-status.sh - Backup Automation Tool: a quick "is everything OK"
# glance - last backup time, last status, how many backups exist, and the
# most recent report's key numbers.
#
# Usage: backup-status.sh [--config=FILE]

set -uo pipefail

_resolve_home() {
    local src="${BASH_SOURCE[0]}"
    while [[ -h "$src" ]]; do
        local dir
        dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="$dir/$src"
    done
    cd -P "$(dirname "$(dirname "$src")")" >/dev/null 2>&1 && pwd
}
readonly BAT_HOME="$(_resolve_home)"

for _arg in "$@"; do
    [[ "$_arg" == "--no-color" ]] && export NO_COLOR=1
done

CONFIG_FILE="$BAT_HOME/config/backup.conf"
for arg in "$@"; do
    case "$arg" in
        --config=*) CONFIG_FILE="${arg#*=}" ;;
        --no-color) : ;;
        -h|--help) echo "Usage: $(basename "$0") [--config=FILE]"; exit 0 ;;
    esac
done

# shellcheck source=../lib/logger.sh
source "$BAT_HOME/lib/logger.sh"
# shellcheck source=../lib/backup-functions.sh
source "$BAT_HOME/lib/backup-functions.sh"

load_config "$CONFIG_FILE"
LOG_FILE="/dev/null"

echo ""
echo "Backup Automation Tool - Status"
echo "=================================================================="

latest_report=$(find "$REPORT_DIR" -maxdepth 1 -type f -name 'backup_report_*.txt' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | awk '{print $2}')

if [[ -z "$latest_report" ]]; then
    echo "  No backup has ever been run (no reports found in $REPORT_DIR)."
    echo "  Run 'backup.sh' to perform your first backup."
    echo ""
    exit 0
fi

report_epoch=$(stat -c '%Y' "$latest_report" 2>/dev/null || echo 0)
now_epoch=$(date +%s)
age_h=$(( (now_epoch - report_epoch) / 3600 ))

status_line=$(grep -m1 '^Status:' "$latest_report" | sed 's/^Status:[[:space:]]*//')
size_line=$(grep -m1 '^Total Backup Size:' "$latest_report" | sed 's/^Total Backup Size:[[:space:]]*//')
dirs_line=$(grep -m1 '^Directories:' "$latest_report" | sed 's/^Directories:[[:space:]]*//')
success_line=$(grep -m1 '^Successful:' "$latest_report" | sed 's/^Successful:[[:space:]]*//')
fail_line=$(grep -m1 '^Failed:' "$latest_report" | sed 's/^Failed:[[:space:]]*//')

archive_count=$(find "$BACKUP_ROOT" -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | wc -l)
archive_total_bytes=0
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    b=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
    archive_total_bytes=$((archive_total_bytes + b))
done < <(find "$BACKUP_ROOT" -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null)

echo "  Last run:            $(date -d "@$report_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?") (${age_h}h ago)"
echo "  Last status:         ${status_line:-unknown}"
echo "  Sources backed up:   ${success_line:-?} succeeded, ${fail_line:-?} failed (of ${dirs_line:-?} configured)"
echo "  Last run size:       ${size_line:-?}"
echo ""
echo "  Backups on disk:     $archive_count archive(s), $(human_readable_size "$archive_total_bytes") total"
echo "  Retention policy:    keep newest $RETENTION_COUNT per source"
echo "  Backup location:     $BACKUP_ROOT"
echo ""
echo "  Full report:         $latest_report"
echo "=================================================================="
echo ""

if [[ "${status_line:-}" != "SUCCESS" ]]; then
    exit 2
fi
exit 0
