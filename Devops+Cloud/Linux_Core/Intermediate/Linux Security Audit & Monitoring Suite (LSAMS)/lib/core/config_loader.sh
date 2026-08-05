#!/usr/bin/env bash
# config_loader.sh - Loads config/lsams.conf and applies safe defaults for
# any setting the file omits, so modules never need to guard for unset vars.

load_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        # shellcheck disable=SC1090
        source "$config_file"
    else
        echo "Config file not found: $config_file (using built-in defaults)" >&2
    fi

    # --- Paths -------------------------------------------------------------
    : "${REPORT_DIR:=$LSAMS_HOME/reports}"
    : "${LOG_DIR:=$LSAMS_HOME/logs}"

    # --- Report options ------------------------------------------------------
    : "${REPORT_FORMATS:=txt,html,json}"
    : "${REPORT_RETENTION_DAYS:=30}"

    # --- Thresholds ----------------------------------------------------------
    : "${CPU_WARN_THRESHOLD:=80}"
    : "${MEM_WARN_THRESHOLD:=80}"
    : "${DISK_WARN_THRESHOLD:=80}"
    : "${DISK_CRIT_THRESHOLD:=90}"
    : "${FAILED_LOGIN_THRESHOLD:=5}"
    : "${FAILED_LOGIN_WINDOW_MIN:=10}"
    : "${ACCOUNT_INACTIVE_DAYS:=90}"

    # --- Alerting --------------------------------------------------------------
    : "${ENABLE_EMAIL_ALERT:=false}"
    : "${ENABLE_SLACK_ALERT:=false}"
    : "${ENABLE_TELEGRAM_ALERT:=false}"
    : "${ALERT_MIN_SCORE:=70}"
    : "${ALERT_EMAIL_TO:=}"
    : "${ALERT_EMAIL_FROM:=lsams@$(hostname -f 2>/dev/null || hostname)}"
    : "${SLACK_WEBHOOK_URL:=}"
    : "${TELEGRAM_BOT_TOKEN:=}"
    : "${TELEGRAM_CHAT_ID:=}"

    # --- Scoring weights ---------------------------------------------------
    : "${SCORE_CRITICAL:=15}"
    : "${SCORE_HIGH:=10}"
    : "${SCORE_MEDIUM:=5}"
    : "${SCORE_LOW:=2}"

    export REPORT_DIR LOG_DIR REPORT_FORMATS REPORT_RETENTION_DAYS
    export CPU_WARN_THRESHOLD MEM_WARN_THRESHOLD DISK_WARN_THRESHOLD DISK_CRIT_THRESHOLD
    export FAILED_LOGIN_THRESHOLD FAILED_LOGIN_WINDOW_MIN ACCOUNT_INACTIVE_DAYS
    export ENABLE_EMAIL_ALERT ENABLE_SLACK_ALERT ENABLE_TELEGRAM_ALERT ALERT_MIN_SCORE
    export ALERT_EMAIL_TO ALERT_EMAIL_FROM SLACK_WEBHOOK_URL TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
    export SCORE_CRITICAL SCORE_HIGH SCORE_MEDIUM SCORE_LOW
}
