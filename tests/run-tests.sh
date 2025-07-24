#!/bin/bash
#
# run-tests.sh - Test runner for change-site project
#
# This script runs all available tests in the proper order:
# 1. Basic functionality tests
# 2. Integration tests
# 3. Enhanced tests (if requested)
#

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd "$TESTS_DIR/.." && pwd)"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Test results
declare -i TOTAL_TEST_SUITES=0
declare -i PASSED_TEST_SUITES=0
declare -i FAILED_TEST_SUITES=0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN} Change-Site Test Runner${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo
}

print_suite_header() {
    local suite_name="$1"
    echo -e "${BLUE}Running $suite_name...${NC}"
    echo "----------------------------------------"
}

run_test_suite() {
    local test_script="$1"
    local suite_name="$2"
    
    ((TOTAL_TEST_SUITES++)) || true
    
    print_suite_header "$suite_name"
    
    if [[ ! -f "$TESTS_DIR/$test_script" ]]; then
        echo -e "${RED}✗ Test script not found: $test_script${NC}"
        ((FAILED_TEST_SUITES++)) || true
        return 1
    fi
    
    if [[ ! -x "$TESTS_DIR/$test_script" ]]; then
        echo -e "${YELLOW}Making $test_script executable...${NC}"
        chmod +x "$TESTS_DIR/$test_script"
    fi
    
    local start_time end_time duration
    start_time=$(date +%s)
    
    # Run the test script directly without capturing output
    if "$TESTS_DIR/$test_script"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo -e "${GREEN}✓ $suite_name completed successfully (${duration}s)${NC}"
        ((PASSED_TEST_SUITES++)) || true
        return 0
    else
        local exit_code=$?
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo -e "${RED}✗ $suite_name failed with exit code $exit_code (${duration}s)${NC}"
        ((FAILED_TEST_SUITES++)) || true
        return 1
    fi
}

print_summary() {
    echo
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN} Test Summary${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo "Total test suites: $TOTAL_TEST_SUITES"
    echo -e "Passed: ${GREEN}$PASSED_TEST_SUITES${NC}"
    echo -e "Failed: ${RED}$FAILED_TEST_SUITES${NC}"
    echo
    
    if [[ $FAILED_TEST_SUITES -eq 0 ]]; then
        echo -e "${GREEN}All test suites passed!${NC}"
        return 0
    else
        echo -e "${RED}Some test suites failed.${NC}"
        return 1
    fi
}

show_usage() {
    cat << EOF
Usage: $0 [options]

Options:
    --basic         Run only basic functionality tests
    --integration   Run only integration tests
    --enhanced      Run only enhanced tests
    --all           Run all test suites (default)
    --help          Show this help message

Test Suites:
    Basic Tests:        Core functionality and syntax validation
    Integration Tests:  Configuration, rollback, and error handling
    Enhanced Tests:     Mock environments and performance testing

Examples:
    $0                  # Run all tests
    $0 --basic          # Run only basic tests
    $0 --integration    # Run only integration tests
    $0 --enhanced       # Run only enhanced tests
EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local run_basic=false
    local run_integration=false
    local run_enhanced=false
    local run_all=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --basic)
                run_basic=true
                run_all=false
                shift
                ;;
            --integration)
                run_integration=true
                run_all=false
                shift
                ;;
            --enhanced)
                run_enhanced=true
                run_all=false
                shift
                ;;
            --all)
                run_all=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_header
    
    # Check if change-site.sh exists
    if [[ ! -f "$PROJECT_DIR/change-site.sh" ]]; then
        echo -e "${RED}ERROR: change-site.sh not found in project directory${NC}"
        exit 1
    fi
    
    # Run test suites based on options
    if [[ "$run_all" == true ]] || [[ "$run_basic" == true ]]; then
        run_test_suite "test-change-site-fixed.sh" "Basic Functionality Tests"
        echo
    fi
    
    if [[ "$run_all" == true ]] || [[ "$run_integration" == true ]]; then
        run_test_suite "test-integration.sh" "Integration Tests"
        echo
    fi
    
    if [[ "$run_all" == true ]] || [[ "$run_enhanced" == true ]]; then
        run_test_suite "test-change-site-enhanced.sh" "Enhanced Tests"
        echo
    fi
    
    print_summary
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi