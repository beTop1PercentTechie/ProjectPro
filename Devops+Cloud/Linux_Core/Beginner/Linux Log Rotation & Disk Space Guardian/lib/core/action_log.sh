#!/usr/bin/env bash
# action_log.sh - The remediation ledger: every rotation, compression,
# deletion, or alert Guardian performs is recorded here so an operator can
# always answer "what did the agent actually do, and when."
#
# Two files are involved:
#   - ACTION_LOG_FILE ($LOG_DIR/actions.log)  - durable, append-only, forever
#   - RUN_ACTIONS_FILE (a per-run temp file)  - this run's actions only, used
#     to build the run's report/summary
#
# Line format: epoch|timestamp|action_type|target|bytes_before|bytes_after|bytes_freed|detail
# Pipe characters inside fields are replaced with the @PIPE@ placeholder so
# they never collide with the column delimiter (plain bash substitution is
# used deliberately - GNU tr has no \xHH hex-escape support, so a naive
# 'tr "|" "\x7c"' silently corrupts unrelated characters).

init_action_log() {
    ACTION_LOG_FILE="$LOG_DIR/actions.log"
    ensure_dir "$LOG_DIR"
    [[ -f "$ACTION_LOG_FILE" ]] || : > "$ACTION_LOG_FILE"

    RUN_ACTIONS_FILE="$(mktemp "${GUARDIAN_TMP_DIR:-/tmp}/guardian_actions.XXXXXX")"
}

_al_escape() {
    local s="$1"
    s="${s//|/@PIPE@}"
    s="${s//$'\n'/ }"
    printf '%s' "$s"
}

# log_action <ACTION_TYPE> <target> <bytes_before> <bytes_after> <detail>
# ACTION_TYPE: ROTATE | COMPRESS | DELETE_OLD_ROTATION | ALERT | SKIP
log_action() {
    local action_type="$1" target="$2" bytes_before="${3:-0}" bytes_after="${4:-0}" detail="$5"
    local bytes_freed=$(( bytes_before - bytes_after ))
    local line
    line=$(printf '%s|%s|%s|%s|%s|%s|%s|%s' \
        "$(epoch_now)" "$(human_date)" "$action_type" \
        "$(_al_escape "$target")" "$bytes_before" "$bytes_after" "$bytes_freed" \
        "$(_al_escape "$detail")")

    echo "$line" >> "$ACTION_LOG_FILE"
    echo "$line" >> "$RUN_ACTIONS_FILE"

    local freed_human
    freed_human="$(bytes_to_human "$bytes_freed")"
    case "$action_type" in
        ALERT) log_warn "[ACTION] $action_type: $target - $detail" ;;
        SKIP)  log_debug "[ACTION] $action_type: $target - $detail" ;;
        *)     log_success "[ACTION] $action_type: $target (freed $freed_human) - $detail" ;;
    esac
}

# total_bytes_freed_this_run - sum of bytes_freed across this run's actions.
total_bytes_freed_this_run() {
    [[ -f "$RUN_ACTIONS_FILE" ]] || { echo 0; return; }
    awk -F'|' '{ sum += $7 } END { print sum+0 }' "$RUN_ACTIONS_FILE"
}

# action_count_this_run [ACTION_TYPE] - count actions of one type, or all.
action_count_this_run() {
    local action_type="${1:-}"
    [[ -f "$RUN_ACTIONS_FILE" ]] || { echo 0; return; }
    if [[ -z "$action_type" ]]; then
        wc -l < "$RUN_ACTIONS_FILE" | tr -d ' '
    else
        awk -F'|' -v t="$action_type" '$3==t { c++ } END { print c+0 }' "$RUN_ACTIONS_FILE"
    fi
}

# run_actions_rows - prints this run's action rows (for report rendering).
run_actions_rows() {
    [[ -f "$RUN_ACTIONS_FILE" ]] || return 0
    cat "$RUN_ACTIONS_FILE"
}

# prune_action_log - keep the durable action log from growing forever.
prune_action_log() {
    [[ -f "$ACTION_LOG_FILE" ]] || return 0
    local cutoff tmp_file
    cutoff=$(( $(epoch_now) - (REPORT_RETENTION_DAYS * 86400) ))
    tmp_file="$(mktemp "${LOG_DIR}/.actions_prune.XXXXXX")"
    awk -F'|' -v cutoff="$cutoff" '($1+0) >= cutoff' "$ACTION_LOG_FILE" > "$tmp_file"
    mv "$tmp_file" "$ACTION_LOG_FILE"
}

cleanup_action_log() {
    [[ -n "${RUN_ACTIONS_FILE:-}" && -f "$RUN_ACTIONS_FILE" ]] && rm -f "$RUN_ACTIONS_FILE"
}
