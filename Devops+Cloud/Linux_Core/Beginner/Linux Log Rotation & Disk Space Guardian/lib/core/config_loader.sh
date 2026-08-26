#!/usr/bin/env bash
# config_loader.sh - Loads config/guardian.conf and applies safe defaults for
# any setting the file omits, so modules never need to guard for unset vars.

load_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        # shellcheck disable=SC1090
        source "$config_file"
    else
        echo "Config file not found: $config_file (using built-in defaults)" >&2
    fi

    # --- Paths ---------------------------------------------------------------
    : "${DATA_DIR:=$GUARDIAN_HOME/data}"
    : "${LOG_DIR:=$GUARDIAN_HOME/logs}"
    : "${REPORT_DIR:=$GUARDIAN_HOME/logs/reports}"
    : "${ROTATION_POLICY_FILE:=$GUARDIAN_HOME/config/rotation_policy.conf}"

    # --- Monitored mount points (comma-separated; "auto" = every local mount) -
    : "${MONITORED_MOUNTS:=auto}"

    # --- Static usage thresholds (percent) ------------------------------------
    : "${DISK_WARN_THRESHOLD:=75}"
    : "${DISK_CRIT_THRESHOLD:=90}"

    # --- Growth-rate trend detection ------------------------------------------
    # Window of history (minutes) used to compute the growth rate.
    : "${GROWTH_SAMPLE_WINDOW_MIN:=60}"
    # Forecast "hours until full" thresholds that trigger a preemptive alert,
    # independent of the current usage percentage.
    : "${FORECAST_WARN_HOURS:=24}"
    : "${FORECAST_CRITICAL_HOURS:=6}"
    # Minimum samples required before a forecast is considered reliable.
    : "${MIN_SAMPLES_FOR_FORECAST:=3}"
    # How long raw history samples are retained.
    : "${HISTORY_RETENTION_DAYS:=30}"

    # --- Space-hog scanning ----------------------------------------------------
    : "${SCAN_PATHS:=/var/log,/home,/tmp,/var/tmp}"
    : "${TOP_N_CONSUMERS:=10}"
    : "${LARGE_FILE_SIZE_MB:=100}"
    : "${DU_MAX_DEPTH:=3}"

    # --- Log rotation defaults (used when no rotation_policy.conf rule matches) -
    : "${DEFAULT_LOG_PATTERN:=/var/log/**/*.log}"
    : "${DEFAULT_MAX_SIZE_MB:=100}"
    : "${DEFAULT_MAX_AGE_DAYS:=14}"
    : "${DEFAULT_KEEP_COUNT:=5}"
    : "${DEFAULT_COMPRESS:=true}"
    # Skip rotating a file that was modified within this many seconds, to
    # avoid truncating a file mid-write.
    : "${ROTATION_QUIET_PERIOD_SEC:=30}"
    : "${DRY_RUN:=false}"

    # --- Alerting ----------------------------------------------------------------
    : "${ENABLE_EMAIL_ALERT:=false}"
    : "${ENABLE_SLACK_ALERT:=false}"
    : "${ENABLE_TELEGRAM_ALERT:=false}"
    : "${ALERT_EMAIL_TO:=}"
    : "${ALERT_EMAIL_FROM:=guardian@$(hostname -f 2>/dev/null || hostname)}"
    : "${SLACK_WEBHOOK_URL:=}"
    : "${TELEGRAM_BOT_TOKEN:=}"
    : "${TELEGRAM_CHAT_ID:=}"
    # Minimum minutes between two alerts for the same mount point, so a
    # 5-minute cron cadence doesn't spam the channel every run.
    : "${ALERT_COOLDOWN_MIN:=60}"

    # --- Report options ------------------------------------------------------------
    : "${REPORT_FORMATS:=txt,json}"
    : "${REPORT_RETENTION_DAYS:=30}"

    export DATA_DIR LOG_DIR REPORT_DIR ROTATION_POLICY_FILE MONITORED_MOUNTS
    export DISK_WARN_THRESHOLD DISK_CRIT_THRESHOLD
    export GROWTH_SAMPLE_WINDOW_MIN FORECAST_WARN_HOURS FORECAST_CRITICAL_HOURS
    export MIN_SAMPLES_FOR_FORECAST HISTORY_RETENTION_DAYS
    export SCAN_PATHS TOP_N_CONSUMERS LARGE_FILE_SIZE_MB DU_MAX_DEPTH
    export DEFAULT_LOG_PATTERN DEFAULT_MAX_SIZE_MB DEFAULT_MAX_AGE_DAYS DEFAULT_KEEP_COUNT
    export DEFAULT_COMPRESS ROTATION_QUIET_PERIOD_SEC DRY_RUN
    export ENABLE_EMAIL_ALERT ENABLE_SLACK_ALERT ENABLE_TELEGRAM_ALERT
    export ALERT_EMAIL_TO ALERT_EMAIL_FROM SLACK_WEBHOOK_URL TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID
    export ALERT_COOLDOWN_MIN REPORT_FORMATS REPORT_RETENTION_DAYS
}
