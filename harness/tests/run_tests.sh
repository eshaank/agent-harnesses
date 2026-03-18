#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_DIR="$(dirname "$TESTS_DIR")"
HOOKS_DIR="$HARNESS_DIR/core/hooks"

PASS=0
FAIL=0

run_test() {
    local test_name="$1"
    local test_file="$2"

    if bash "$test_file"; then
        echo -e "  ${GREEN}PASS${NC}: $test_name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${NC}: $test_name"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Hook Test Suite ==="
echo ""

for test_file in "$TESTS_DIR"/test_*.sh; do
    if [ -f "$test_file" ]; then
        test_name=$(basename "$test_file" .sh)
        run_test "$test_name" "$test_file"
    fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
