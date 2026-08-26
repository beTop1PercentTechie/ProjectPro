#!/usr/bin/env bash
# guardian.sh - Linux Log Rotation & Disk Space Guardian
#
# Entry point: parses CLI options, loads configuration, runs the selected
# modules in dependency order, renders a report, and dispatches alerts.
# Run via `bin/diskguardian` or directly as `./guardian.sh`.
#
# Usage: guardian.sh [OPTIONS]
# Run 'guardian.sh --help' for the full option list.

set -uo pipefail

# --- Resolve GUARDIAN_HOME regardless of symlinks or invocation directory ----
_resolve_home() {
    local src="${BASH_SOURCE[0]}"
    while [[ -h "$src" ]]; do
        local dir
        dir="$(cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="$dir/$src"
    done
    cd -P "$(dirname "$src")" >/dev/null 2>&1 && pwd
}
readonly GUARDIAN_HOME="$(_resolve_home)"
readonly GUARDIAN_VERSION="1.0.0"

# --no-color must take effect before colors.sh is sourced (its color vars are
# readonly, so sourcing it twice would abort with a "readonly variable" error).
for _arg in "$@"; do
    [[ "$_arg" == "--no-color" ]] && export NO_COLOR=1
done

# --- Load core library --------------------------------------------------------
# shellcheck source=lib/core/colors.sh
source "$GUARDIAN_HOME/lib/core/colors.sh"
# shellcheck source=lib/core/utils.sh
source "$GUARDIAN_HOME/lib/core/utils.sh"
# shellcheck source=lib/core/config_loader.sh
source "$GUARDIAN_HOME/lib/core/config_loader.sh"

# --- Module registry: key:function:file, listed in required run order --------
# 'alert' depends on the per-mount metrics 'track' computes this run, so the
# registry order (not the order the user lists --modules=) is what executes.
readonly MODULE_REGISTRY=(
    "track:run_disk_tracker:01_disk_tracker.sh"
    "hogs:run_space_hogs:02_space_hogs.sh"
    "rotate:run_log_rotator:03_log_rotator.sh"
    "alert:run_alerting:04_alerting.sh"
)
readonly MONITOR_MODULES="track,alert"

print_usage() {
    cat <<USAGE
Linux Log Rotation & Disk Space Guardian v${GUARDIAN_VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
  --full                  Run every module: track, hogs, rotate, alert (default)
  --monitor               Fast subset for frequent cron runs: ${MONITOR_MODULES}
  --modules=LIST          Run a specific comma-separated list of modules
  --list-modules          Show available module keys and exit
  --format=LIST           Report formats to generate: txt,html,json (default: from config)
  --output-dir=DIR        Override the report output directory
  --config=FILE           Use an alternate config file (default: config/guardian.conf)
  --dry-run               Force DRY_RUN=true for this run (log intended actions, touch nothing)
  --email                 Force-enable the email alert for this run
  --slack                 Force-enable the Slack alert for this run
  --telegram              Force-enable the Telegram alert for this run
  --no-color              Disable colored console output
  -h, --help              Show this help message
  -V, --version           Show version information

Suggested cron cadence:
  */5  * * * *  guardian --monitor   # real-time tracking + preemptive alerts
  0 3  * * *    guardian --full      # full sweep: space-hog scan + log rotation

Examples:
  sudo $(basename "$0") --monitor
  sudo $(basename "$0") --full
  sudo $(basename "$0") --modules=rotate --dry-run
USAGE
}

CONFIG_FILE="$GUARDIAN_HOME/config/guardian.conf"
SELECTED_MODULES=""
RUN_MODE="full"
FORMAT_OVERRIDE=""
OUTPUT_DIR_OVERRIDE=""
FORCE_DRY_RUN=false
FORCE_EMAIL=false
FORCE_SLACK=false
FORCE_TELEGRAM=false

for arg in "$@"; do
    case "$arg" in
        --full) RUN_MODE="full" ;;
        --monitor) RUN_MODE="monitor" ;;
        --modules=*) RUN_MODE="custom"; SELECTED_MODULES="${arg#*=}" ;;
        --list-modules)
            printf 'Available modules:\n'
            for entry in "${MODULE_REGISTRY[@]}"; do printf '  - %s\n' "${entry%%:*}"; done
            exit 0
            ;;
        --format=*) FORMAT_OVERRIDE="${arg#*=}" ;;
        --output-dir=*) OUTPUT_DIR_OVERRIDE="${arg#*=}" ;;
        --config=*) CONFIG_FILE="${arg#*=}" ;;
        --dry-run) FORCE_DRY_RUN=true ;;
        --email) FORCE_EMAIL=true ;;
        --slack) FORCE_SLACK=true ;;
        --telegram) FORCE_TELEGRAM=true ;;
        --no-color) : ;; # already applied above, before colors.sh was sourced
        -h|--help) print_usage; exit 0 ;;
        -V|--version) echo "Guardian v${GUARDIAN_VERSION}"; exit 0 ;;
        *)
            echo "Unknown option: $arg" >&2
            print_usage
            exit 1
            ;;
    esac
done

require_root
load_config "$CONFIG_FILE"

[[ -n "$FORMAT_OVERRIDE" ]] && REPORT_FORMATS="$FORMAT_OVERRIDE"
[[ -n "$OUTPUT_DIR_OVERRIDE" ]] && REPORT_DIR="$OUTPUT_DIR_OVERRIDE"
[[ "$FORCE_DRY_RUN" == "true" ]] && DRY_RUN=true
[[ "$FORCE_EMAIL" == "true" ]] && ENABLE_EMAIL_ALERT=true
[[ "$FORCE_SLACK" == "true" ]] && ENABLE_SLACK_ALERT=true
[[ "$FORCE_TELEGRAM" == "true" ]] && ENABLE_TELEGRAM_ALERT=true

ensure_dir "$LOG_DIR"
ensure_dir "$DATA_DIR"
ensure_dir "$REPORT_DIR"
GUARDIAN_TMP_DIR="${LOG_DIR}/.tmp"
ensure_dir "$GUARDIAN_TMP_DIR"

LOG_FILE="${LOG_DIR}/guardian_$(timestamp_now).log"
: > "$LOG_FILE"

# shellcheck source=lib/core/logger.sh
source "$GUARDIAN_HOME/lib/core/logger.sh"
# shellcheck source=lib/core/history_store.sh
source "$GUARDIAN_HOME/lib/core/history_store.sh"
# shellcheck source=lib/core/events.sh
source "$GUARDIAN_HOME/lib/core/events.sh"
# shellcheck source=lib/core/action_log.sh
source "$GUARDIAN_HOME/lib/core/action_log.sh"
# shellcheck source=lib/core/report_engine.sh
source "$GUARDIAN_HOME/lib/core/report_engine.sh"

for alert_script in "$GUARDIAN_HOME"/alerts/*.sh; do
    # shellcheck disable=SC1090
    source "$alert_script"
done

init_history_store
init_event_store
init_action_log

trap 'cleanup_event_store; cleanup_action_log; cleanup_mount_metrics; cleanup_notify_file' EXIT

# --- Determine which modules to run -------------------------------------------
case "$RUN_MODE" in
    full)    SELECTED_MODULES="$(printf '%s,' "${MODULE_REGISTRY[@]%%:*}")" ;;
    monitor) SELECTED_MODULES="$MONITOR_MODULES" ;;
    custom)  : ;; # already set from --modules=
esac

log_info "Linux Log Rotation & Disk Space Guardian v${GUARDIAN_VERSION} starting ($RUN_MODE mode)"
[[ "$DRY_RUN" == "true" ]] && log_warn "DRY-RUN mode: no files will be rotated, compressed, or deleted"

IFS=',' read -ra requested <<< "$SELECTED_MODULES"
for entry in "${MODULE_REGISTRY[@]}"; do
    key="${entry%%:*}"
    rest="${entry#*:}"
    fn="${rest%%:*}"
    file="${rest#*:}"

    wanted=false
    for mod_key in "${requested[@]}"; do
        [[ "$(trim "$mod_key")" == "$key" ]] && wanted=true && break
    done
    [[ "$wanted" == "false" ]] && continue

    # shellcheck disable=SC1090
    source "$GUARDIAN_HOME/lib/modules/$file"
    "$fn"
done

section "Run Summary"
generate_reports
log_info "Overall Status: ${LAST_REPORT_STATUS}  |  Space freed this run: $(bytes_to_human "$(total_bytes_freed_this_run)")"

report_file_path="${REPORT_DIR}/${LAST_REPORT_BASENAME}.txt"

if [[ -n "${NOTIFY_FILE:-}" && -s "$NOTIFY_FILE" ]]; then
    notify_status="WARNING"
    grep -q '|CRITICAL|' "$NOTIFY_FILE" && notify_status="CRITICAL"
    notify_summary="$(awk -F'|' '{ printf "- %s: %s (%s)\n", $1, $2, $3 }' "$NOTIFY_FILE")"

    send_email_alert    "$notify_status" "$report_file_path" "$notify_summary" || true
    send_slack_alert    "$notify_status" "$report_file_path" "$notify_summary" || true
    send_telegram_alert "$notify_status" "$report_file_path" "$notify_summary" || true
fi

prune_action_log

if (( REPORT_RETENTION_DAYS > 0 )); then
    find "$REPORT_DIR" -type f -mtime "+${REPORT_RETENTION_DAYS}" -name 'guardian_report_*' -delete 2>/dev/null
fi

log_info "Run complete. Log file: $LOG_FILE"

case "$LAST_REPORT_STATUS" in
    CRITICAL) exit 2 ;;
    WARNING)  exit 3 ;;
    *)        exit 0 ;;
esac
