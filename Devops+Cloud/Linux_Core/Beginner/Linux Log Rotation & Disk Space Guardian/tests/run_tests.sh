#!/usr/bin/env bash
# run_tests.sh - Discovers and runs every tests/test_*.sh file, then reports
# a pass/fail summary. Exits non-zero if any suite fails (CI-friendly).

set -uo pipefail

TEST_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

suite_count=0
failed_suites=0

for suite in "$TEST_DIR"/test_*.sh; do
    [[ -f "$suite" ]] || continue
    suite_count=$((suite_count + 1))
    echo "=== Running $(basename "$suite") ==="
    if bash "$suite"; then
        echo "=== PASS: $(basename "$suite") ==="
    else
        echo "=== FAIL: $(basename "$suite") ==="
        failed_suites=$((failed_suites + 1))
    fi
    echo
done

echo "Suites run: $suite_count, failed: $failed_suites"
[[ "$failed_suites" -eq 0 ]]
