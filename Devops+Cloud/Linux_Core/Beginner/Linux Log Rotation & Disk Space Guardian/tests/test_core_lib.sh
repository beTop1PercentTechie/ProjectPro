#!/usr/bin/env bash
# test_core_lib.sh - Unit tests for lib/core/*.sh. Pure bash, no external
# test framework required. Run via tests/run_tests.sh.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
GUARDIAN_HOME="$(cd -P "$TEST_DIR/.." >/dev/null 2>&1 && pwd)"

# shellcheck source=../lib/core/colors.sh
source "$GUARDIAN_HOME/lib/core/colors.sh"
# shellcheck source=../lib/core/utils.sh
source "$GUARDIAN_HOME/lib/core/utils.sh"

LOG_FILE="$(mktemp)"
# shellcheck source=../lib/core/logger.sh
source "$GUARDIAN_HOME/lib/core/logger.sh"
# shellcheck source=../lib/core/events.sh
source "$GUARDIAN_HOME/lib/core/events.sh"
# shellcheck source=../lib/core/action_log.sh
source "$GUARDIAN_HOME/lib/core/action_log.sh"

DATA_DIR="$(mktemp -d)"
GUARDIAN_TMP_DIR="$(mktemp -d)"
LOG_DIR="$(mktemp -d)"
REPORT_RETENTION_DAYS=30
# shellcheck source=../lib/core/history_store.sh
source "$GUARDIAN_HOME/lib/core/history_store.sh"

TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$expected" == "$actual" ]]; then
        echo "  ok - $label"
    else
        echo "  FAIL - $label (expected '$expected', got '$actual')"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "== utils.sh =="
assert_eq "hello" "$(trim '  hello  ')" "trim strips surrounding whitespace"
assert_eq "abc" "$(to_lower 'ABC')" "to_lower lowercases input"
assert_eq "512 KB" "$(kb_to_human 512)" "kb_to_human renders sub-1MB as KB"
assert_eq "2.00 MB" "$(kb_to_human 2048)" "kb_to_human renders MB correctly"
assert_eq "1.00 KB" "$(bytes_to_human 1024)" "bytes_to_human renders KB correctly"
assert_eq "1h 30m" "$(seconds_to_human 5400)" "seconds_to_human renders hours+minutes"
assert_eq "45m" "$(seconds_to_human 2700)" "seconds_to_human renders minutes only"

echo "== history_store.sh: growth-rate trend detection =="
init_history_store

now=$(epoch_now)
one_hour_ago=$(( now - 3600 ))
{
    printf '%s,%s,%s,%s,%s,%s\n' "$one_hour_ago" "/data" 1000 9000 10000 10
    printf '%s,%s,%s,%s,%s,%s\n' "$now"           "/data" 1500 8500 10000 15
} >> "$HISTORY_FILE"

assert_eq "2" "$(sample_count_in_window /data 120)" "both samples fall inside a 120-minute window"
assert_eq "500" "$(growth_rate_kb_per_hour /data 120)" "growth rate = (1500-1000)KB / 1 hour = 500 KB/hour"
assert_eq "17.0" "$(forecast_hours_to_full 8500 500)" "forecast: 8500KB avail / 500KB/hour = 17.0h"
assert_eq "inf" "$(forecast_hours_to_full 8500 0)" "forecast is 'inf' when growth rate is zero or negative"

# A lone sample (no second point in the window) can't produce a rate.
init_history_store
printf '%s,%s,%s,%s,%s,%s\n' "$now" "/solo" 1000 9000 10000 10 >> "$HISTORY_FILE"
assert_eq "0" "$(growth_rate_kb_per_hour /solo 120)" "growth rate is 0 with only one sample in the window"

echo "== events.sh =="
init_event_store
assert_eq "0" "$(count_events_by_severity CRITICAL)" "no events recorded initially"
add_event "CRITICAL" "Alert" "/ is almost full" "97% used" >/dev/null
add_event "WARNING" "Alert" "/var growing fast" "projected full in 4h" >/dev/null
assert_eq "1" "$(count_events_by_severity CRITICAL)" "one critical event recorded"
assert_eq "CRITICAL" "$(overall_status)" "overall_status is CRITICAL when any critical event exists"
cleanup_event_store

init_event_store
add_event "WARNING" "Alert" "/var growing fast" "projected full in 4h" >/dev/null
assert_eq "WARNING" "$(overall_status)" "overall_status is WARNING when no critical but a warning exists"
cleanup_event_store

echo "== action_log.sh =="
init_action_log
log_action "ROTATE" "/var/log/app.log" 104857600 0 "trigger: size 100MB" >/dev/null
log_action "DELETE_OLD_ROTATION" "/var/log/app.log.old.gz" 5242880 0 "beyond retention" >/dev/null
assert_eq "2" "$(action_count_this_run)" "two actions recorded this run"
assert_eq "1" "$(action_count_this_run ROTATE)" "one ROTATE action recorded"
assert_eq "110100480" "$(total_bytes_freed_this_run)" "total bytes freed sums both actions"
cleanup_action_log

rm -f "$LOG_FILE"
rm -rf "$DATA_DIR" "$GUARDIAN_TMP_DIR" "$LOG_DIR"

echo
echo "Tests run: $TESTS_RUN, failed: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
