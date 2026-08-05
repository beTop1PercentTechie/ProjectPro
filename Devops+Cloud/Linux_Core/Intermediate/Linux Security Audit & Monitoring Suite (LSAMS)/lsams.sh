#!/usr/bin/env bash
# lsams.sh - Linux Security Audit & Monitoring Suite
#
# Entry point: parses CLI options, loads configuration, runs the selected
# audit modules, renders reports, and dispatches alerts. Run via `bin/lsams`
# or directly as `./lsams.sh`.
#
# Usage: lsams.sh [OPTIONS]
# Run 'lsams.sh --help' for the full option list.

set -uo pipefail

# --- Resolve LSAMS_HOME regardless of symlinks or invocation directory -------
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
readonly LSAMS_HOME="$(_resolve_home)"
readonly LSAMS_VERSION="1.0.0"

# --no-color must take effect before colors.sh is sourced (its color vars are
# readonly, so sourcing it twice would abort with a "readonly variable" error).
for _arg in "$@"; do
    [[ "$_arg" == "--no-color" ]] && export NO_COLOR=1
done

# --- Load core library --------------------------------------------------------
# shellcheck source=lib/core/colors.sh
source "$LSAMS_HOME/lib/core/colors.sh"
# shellcheck source=lib/core/utils.sh
source "$LSAMS_HOME/lib/core/utils.sh"
# shellcheck source=lib/core/config_loader.sh
source "$LSAMS_HOME/lib/core/config_loader.sh"

# --- Module registry: key:function:file --------------------------------------
readonly MODULE_REGISTRY=(
    "users:run_user_audit:01_user_audit.sh"
    "ssh:run_ssh_audit:02_ssh_audit.sh"
    "permissions:run_file_permissions_audit:03_file_permissions.sh"
    "health:run_system_health_audit:04_system_health.sh"
    "network:run_network_audit:05_network_audit.sh"
    "authlog:run_auth_log_analysis:06_auth_log_analysis.sh"
    "packages:run_package_kernel_audit:07_package_kernel_audit.sh"
    "compliance:run_compliance_check:08_compliance_check.sh"
    "services:run_service_audit:09_service_audit.sh"
)
readonly QUICK_MODULES="health,network,services"

print_usage() {
    cat <<USAGE
Linux Security Audit & Monitoring Suite (LSAMS) v${LSAMS_VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
  --full                  Run every audit module (default)
  --quick                 Run a fast subset only (${QUICK_MODULES})
  --modules=LIST          Run a specific comma-separated list of modules
  --list-modules          Show available module keys and exit
  --format=LIST           Report formats to generate: txt,html,json (default: from config)
  --output-dir=DIR        Override the report output directory
  --config=FILE           Use an alternate config file (default: config/lsams.conf)
  --email                 Force-enable the email alert for this run
  --slack                 Force-enable the Slack alert for this run
  --telegram              Force-enable the Telegram alert for this run
  --no-color              Disable colored console output
  -h, --help              Show this help message
  -V, --version           Show version information

Examples:
  sudo $(basename "$0") --full
  sudo $(basename "$0") --quick
  sudo $(basename "$0") --modules=ssh,network --format=json
USAGE
}

CONFIG_FILE="$LSAMS_HOME/config/lsams.conf"
SELECTED_MODULES=""
RUN_MODE="full"
FORMAT_OVERRIDE=""
OUTPUT_DIR_OVERRIDE=""
FORCE_EMAIL=false
FORCE_SLACK=false
FORCE_TELEGRAM=false

for arg in "$@"; do
    case "$arg" in
        --full) RUN_MODE="full" ;;
        --quick) RUN_MODE="quick" ;;
        --modules=*) RUN_MODE="custom"; SELECTED_MODULES="${arg#*=}" ;;
        --list-modules)
            printf 'Available modules:\n'
            for entry in "${MODULE_REGISTRY[@]}"; do printf '  - %s\n' "${entry%%:*}"; done
            exit 0
            ;;
        --format=*) FORMAT_OVERRIDE="${arg#*=}" ;;
        --output-dir=*) OUTPUT_DIR_OVERRIDE="${arg#*=}" ;;
        --config=*) CONFIG_FILE="${arg#*=}" ;;
        --email) FORCE_EMAIL=true ;;
        --slack) FORCE_SLACK=true ;;
        --telegram) FORCE_TELEGRAM=true ;;
        --no-color) : ;; # already applied above, before colors.sh was sourced
        -h|--help) print_usage; exit 0 ;;
        -V|--version) echo "LSAMS v${LSAMS_VERSION}"; exit 0 ;;
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
[[ "$FORCE_EMAIL" == "true" ]] && ENABLE_EMAIL_ALERT=true
[[ "$FORCE_SLACK" == "true" ]] && ENABLE_SLACK_ALERT=true
[[ "$FORCE_TELEGRAM" == "true" ]] && ENABLE_TELEGRAM_ALERT=true

ensure_dir "$LOG_DIR"
ensure_dir "$REPORT_DIR"
LSAMS_TMP_DIR="${LOG_DIR}/.tmp"
ensure_dir "$LSAMS_TMP_DIR"

LOG_FILE="${LOG_DIR}/lsams_$(timestamp_now).log"
: > "$LOG_FILE"

# shellcheck source=lib/core/logger.sh
source "$LSAMS_HOME/lib/core/logger.sh"
# shellcheck source=lib/core/findings.sh
source "$LSAMS_HOME/lib/core/findings.sh"
# shellcheck source=lib/core/report_engine.sh
source "$LSAMS_HOME/lib/core/report_engine.sh"

for alert_script in "$LSAMS_HOME"/alerts/*.sh; do
    # shellcheck disable=SC1090
    source "$alert_script"
done

init_findings_store
trap cleanup_findings_store EXIT

# --- Determine which modules to run -------------------------------------------
case "$RUN_MODE" in
    full)   SELECTED_MODULES="$(printf '%s,' "${MODULE_REGISTRY[@]%%:*}")" ;;
    quick)  SELECTED_MODULES="$QUICK_MODULES" ;;
    custom) : ;; # already set from --modules=
esac

log_info "Linux Security Audit & Monitoring Suite v${LSAMS_VERSION} starting ($RUN_MODE mode)"
log_info "Host: $(os_pretty_name) | Kernel: $(uname -r)"

IFS=',' read -ra requested <<< "$SELECTED_MODULES"
for mod_key in "${requested[@]}"; do
    mod_key="$(trim "$mod_key")"
    [[ -z "$mod_key" ]] && continue

    found=false
    for entry in "${MODULE_REGISTRY[@]}"; do
        key="${entry%%:*}"
        rest="${entry#*:}"
        fn="${rest%%:*}"
        file="${rest#*:}"

        if [[ "$key" == "$mod_key" ]]; then
            found=true
            # shellcheck disable=SC1090
            source "$LSAMS_HOME/lib/modules/$file"
            "$fn"
            break
        fi
    done

    [[ "$found" == "false" ]] && log_warn "Unknown module requested: '$mod_key' (skipped)"
done

section "Audit Summary"
generate_reports
log_info "Security Score: ${LAST_REPORT_SCORE}/100  |  Risk Rating: ${LAST_REPORT_RISK}"

report_file_path="${REPORT_DIR}/${LAST_REPORT_BASENAME}.txt"
report_html_path="${REPORT_DIR}/${LAST_REPORT_BASENAME}.html"

# Prefer attaching the styled HTML report to the email; fall back to the
# plain-text report if HTML wasn't in REPORT_FORMATS for this run.
email_attachment_path="$report_file_path"
[[ -f "$report_html_path" ]] && email_attachment_path="$report_html_path"

score_below_threshold=false
(( LAST_REPORT_SCORE < ALERT_MIN_SCORE )) && score_below_threshold=true

if [[ "$score_below_threshold" == "true" ]]; then
    send_email_alert    "$LAST_REPORT_SCORE" "$LAST_REPORT_RISK" "$report_file_path" "$email_attachment_path" || true
    send_slack_alert    "$LAST_REPORT_SCORE" "$LAST_REPORT_RISK" "$report_file_path" || true
    send_telegram_alert "$LAST_REPORT_SCORE" "$LAST_REPORT_RISK" "$report_file_path" || true
else
    log_info "Score ${LAST_REPORT_SCORE}/100 is at or above ALERT_MIN_SCORE (${ALERT_MIN_SCORE}) - no alert dispatched"
fi

if (( REPORT_RETENTION_DAYS > 0 )); then
    find "$REPORT_DIR" -type f -mtime "+${REPORT_RETENTION_DAYS}" -name 'lsams_report_*' -delete 2>/dev/null
fi

log_info "Audit complete. Log file: $LOG_FILE"

if [[ "$score_below_threshold" == "true" ]]; then
    exit 2
fi
exit 0
