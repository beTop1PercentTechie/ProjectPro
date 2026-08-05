#!/usr/bin/env bash
# test_core_lib.sh - Unit tests for lib/core/*.sh. Pure bash, no external
# test framework required. Run via tests/run_tests.sh.

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LSAMS_HOME="$(cd -P "$TEST_DIR/.." >/dev/null 2>&1 && pwd)"

# shellcheck source=../lib/core/colors.sh
source "$LSAMS_HOME/lib/core/colors.sh"
# shellcheck source=../lib/core/utils.sh
source "$LSAMS_HOME/lib/core/utils.sh"

LOG_FILE="$(mktemp)"
# shellcheck source=../lib/core/logger.sh
source "$LSAMS_HOME/lib/core/logger.sh"
# shellcheck source=../lib/core/findings.sh
source "$LSAMS_HOME/lib/core/findings.sh"

SCORE_CRITICAL=15; SCORE_HIGH=10; SCORE_MEDIUM=5; SCORE_LOW=2

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

echo "== findings.sh =="
init_findings_store >/dev/null

assert_eq "0" "$(count_findings_by_severity CRITICAL)" "no findings recorded initially"

add_finding "CRITICAL" "TestModule" "Critical issue" "detail" "fix it" >/dev/null
add_finding "HIGH" "TestModule" "High issue" "detail" "fix it" >/dev/null
add_finding "MEDIUM" "TestModule" "Medium issue" "detail" "fix it" >/dev/null
add_finding "LOW" "TestModule" "Low issue" "detail" "fix it" >/dev/null

assert_eq "1" "$(count_findings_by_severity CRITICAL)" "one critical finding recorded"
assert_eq "1" "$(count_findings_by_severity HIGH)" "one high finding recorded"

# 100 - 15(crit) - 10(high) - 5(med) - 2(low) = 68
assert_eq "68" "$(compute_security_score)" "security score deducts weighted points per severity"
assert_eq "HIGH" "$(risk_rating_for_score 68)" "score 68 maps to HIGH risk"
assert_eq "LOW" "$(risk_rating_for_score 95)" "score 95 maps to LOW risk"
assert_eq "CRITICAL" "$(risk_rating_for_score 10)" "score 10 maps to CRITICAL risk"

cleanup_findings_store
rm -f "$LOG_FILE"

echo
echo "Tests run: $TESTS_RUN, failed: $TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
