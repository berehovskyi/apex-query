#!/bin/bash

# Unified E2E Apex script runner.
# Usage:
#   bash e2e/run_tests.sh <suite> [org_alias]
#
# Suites:
#   - soql
#   - soql-external
#   - sql
#   - cdp
#   - all          (soql + soql-external + sql)
#   - all-with-cdp (soql + soql-external + sql + cdp)

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

SUITE="${1:-all}"
ORG_ALIAS="${2:-}"

export SF_DISABLE_LOG_FILE=true

suite_dir() {
    case "$1" in
    soql) echo "e2e/test/soql" ;;
    soql-external) echo "e2e/test/soql-external" ;;
    sql) echo "e2e/test/sql" ;;
    cdp) echo "e2e/test/cdp" ;;
    *) return 1 ;;
    esac
}

run_suite() {
    local suite="$1"
    local test_dir
    test_dir="$(suite_dir "$suite")" || {
        echo -e "${RED}Unknown suite: ${suite}${NC}"
        return 2
    }

    local target_org_args=()
    if [[ -n "$ORG_ALIAS" ]]; then
        target_org_args=(-o "$ORG_ALIAS")
    fi

    echo -e "${BLUE}=== Running ${suite} E2E Test Suite ===${NC}"
    if [[ -n "$ORG_ALIAS" ]]; then
        echo -e "Using org alias: ${ORG_ALIAS}"
    fi

    local passed=0
    local failed=0
    local total=0
    local test_found=0

    for test_file in "$test_dir"/*.apex; do
        if [[ ! -e "$test_file" ]]; then
            continue
        fi
        test_found=1
        ((total++))
        local filename
        filename=$(basename "$test_file")
        echo -n "Running $filename... "

        local output
        output=$(sf apex run -f "$test_file" "${target_org_args[@]}" 2>&1)

        if [[ $? -eq 0 && "$output" == *"Passed"* ]]; then
            echo -e "${GREEN}PASSED${NC}"
            ((passed++))
        else
            echo -e "${RED}FAILED${NC}"
            echo -e "Error details: $output"
            ((failed++))
        fi
    done

    if [[ $test_found -eq 0 ]]; then
        echo -e "${YELLOW}No .apex files found in ${test_dir}${NC}"
        return 1
    fi

    echo -e "${BLUE}=== ${suite} Test Summary ===${NC}"
    echo -e "Total: $total"
    echo -e "${GREEN}Passed: $passed${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}Failed: $failed${NC}"
        return 1
    fi

    echo -e "${GREEN}All ${suite} tests passed!${NC}"
    return 0
}

case "$SUITE" in
all)
    suites=(soql soql-external sql)
    ;;
all-with-cdp)
    suites=(soql soql-external sql cdp)
    ;;
soql | soql-external | sql | cdp)
    suites=("$SUITE")
    ;;
*)
    echo -e "${RED}Invalid suite: ${SUITE}${NC}"
    echo "Usage: bash e2e/run_tests.sh <soql|soql-external|sql|cdp|all|all-with-cdp> [org_alias]"
    exit 2
    ;;
esac

overall_failed=0
for s in "${suites[@]}"; do
    if ! run_suite "$s"; then
        overall_failed=1
    fi
done

exit $overall_failed
