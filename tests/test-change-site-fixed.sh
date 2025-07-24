#!/bin/bash
#
# test-change-site-fixed.sh - Fixed version of the test script
#

set -uo pipefail

# =============================================================================
# TEST FRAMEWORK CONFIGURATION  
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CHANGE_SITE_SCRIPT="$SCRIPT_DIR/change-site.sh"
readonly TEST_LOG="/tmp/change-site-test.log"
readonly TEST_TEMP_DIR="/tmp/change-site-tests"

# Test counters
declare -i TESTS_RUN=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

setup_test_environment() {
    echo "Setting up test environment..."
    mkdir -p "$TEST_TEMP_DIR"
    echo "Test environment ready"
}

cleanup_test_environment() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_TEMP_DIR"
    echo "Cleanup complete"
}

# Set up cleanup trap
trap cleanup_test_environment EXIT

log_test() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$TEST_LOG"
}

assert_exit_code() {
    local expected_code="$1"
    local actual_code="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    
    if [[ "$expected_code" -eq "$actual_code" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        log_test "PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected exit code: $expected_code"
        echo -e "  Actual exit code:   $actual_code"
        log_test "FAIL: $test_name - Expected exit code: $expected_code, Actual: $actual_code"
        ((TESTS_FAILED++))
        return 1
    fi
}

# =============================================================================
# TEST FUNCTIONS
# =============================================================================

test_script_syntax() {
    echo -e "\n${BLUE}Testing script syntax...${NC}"
    
    local output exit_code=0
    
    # Test bash syntax
    output=$(bash -n "$CHANGE_SITE_SCRIPT" 2>&1) || exit_code=$?
    assert_exit_code 0 "$exit_code" "Script should have valid bash syntax" || true
}

test_help_option() {
    echo -e "\n${BLUE}Testing help option...${NC}"
    
    local output exit_code=0
    output=$(timeout 5 "$CHANGE_SITE_SCRIPT" --help 2>&1) || exit_code=$?
    assert_exit_code 0 "$exit_code" "Help option should work" || true
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

run_all_tests() {
    echo -e "${BLUE}Starting comprehensive tests for change-site script${NC}"
    echo "============================================================"
    
    setup_test_environment
    
    # Check if script exists
    if [[ ! -f "$CHANGE_SITE_SCRIPT" ]]; then
        echo -e "${RED}ERROR: Script not found: $CHANGE_SITE_SCRIPT${NC}"
        exit 1
    fi
    
    # Run tests (with || true to continue on failure)
    test_script_syntax || true
    test_help_option || true
    
    # Print summary
    echo
    echo "============================================================"
    echo -e "${BLUE}Test Summary${NC}"
    echo "============================================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed. Check the output above for details.${NC}"
        echo "Test log available at: $TEST_LOG"
        exit 1
    fi
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests "$@"
fi