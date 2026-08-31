#!/usr/bin/env bash
# list-backups.sh - Backup Automation Tool: shows every backup currently
# stored in BACKUP_ROOT, newest first, with size and age.
#
# Usage: list-backups.sh [--config=FILE]

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

mapfile -t archives < <(find "$BACKUP_ROOT" -maxdepth 1 -type f -name '*.tar.gz' -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk '{print $2}')

echo ""
echo "Available Backups (${BACKUP_ROOT})"
echo "=================================================================="

if [[ ${#archives[@]} -eq 0 ]]; then
    echo "  (none found)"
    echo ""
    exit 0
fi

now_epoch=$(date +%s)
idx=0
total_bytes=0
for a in "${archives[@]}"; do
    idx=$((idx + 1))
    bytes=$(stat -c '%s' "$a" 2>/dev/null || echo 0)
    mtime=$(stat -c '%Y' "$a" 2>/dev/null || echo "$now_epoch")
    age_h=$(( (now_epoch - mtime) / 3600 ))
    total_bytes=$((total_bytes + bytes))
    printf '  %2d. %-45s %10s   %s (%dh ago)\n' \
        "$idx" "$(basename "$a")" "$(human_readable_size "$bytes")" \
        "$(date -d "@$mtime" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "?")" "$age_h"
done

echo "=================================================================="
echo "  Total: ${idx} backup(s), $(human_readable_size "$total_bytes")"
echo ""
