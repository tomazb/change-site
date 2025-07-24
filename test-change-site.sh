#!/bin/bash
#
# test-change-site.sh - Unit tests for change-site script
#
# This script provides comprehensive testing for the refactored change-site.sh
# Compatible with RHEL 8, 9, and 10
#

set -euo pipefail

# =============================================================================
# TEST FRAMEWORK CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
# TEST FRAMEWORK FUNCTIONS
# =============================================================================

setup_test_environment() {
    echo "Setting up test environment..."
    
    # Create test directory
    mkdir -p "$TEST_TEMP_DIR"
    chmod 700 "$TEST_TEMP_DIR"
    
    # Clear test log
    > "$TEST_LOG"
    
    echo "Test environment ready"
}

cleanup_test_environment() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_TEMP_DIR"
    echo "Cleanup complete"
}

trap cleanup_test_environment EXIT

log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$TEST_LOG"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        log_test "PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        log_test "FAIL: $test_name - Expected: $expected, Actual: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        log_test "PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Haystack: $haystack"
        echo -e "  Needle:   $needle"
        log_test "FAIL: $test_name - '$needle' not found in '$haystack'"
        ((TESTS_FAILED++))
        return 1
    fi
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

run_change_site() {
    local args="$*"
    local output_file="$TEST_TEMP_DIR/output.txt"
    local exit_code
    
    # Run the script and capture output and exit code
    if "$CHANGE_SITE_SCRIPT" $args > "$output_file" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # Return output and exit code
    cat "$output_file"
    return $exit_code
}

# =============================================================================
# BASIC FUNCTIONALITY TESTS
# =============================================================================

test_help_option() {
    echo -e "\n${BLUE}Testing help option...${NC}"
    
    local output
    local exit_code
    
    output=$(run_change_site "--help" 2>&1) || exit_code=$?
    
    assert_exit_code 0 ${exit_code:-0} "Help option should exit with code 0"
    assert_contains "$output" "Usage:" "Help should contain usage information"
    assert_contains "$output" "change-site" "Help should contain script name"
}

test_version_option() {
    echo -e "\n${BLUE}Testing version option...${NC}"
    
    local output
    local exit_code
    
    output=$(run_change_site "--version" 2>&1) || exit_code=$?
    
    assert_exit_code 0 ${exit_code:-0} "Version option should exit with code 0"
    assert_contains "$output" "version" "Version should contain version information"
}

test_invalid_arguments() {
    echo -e "\n${BLUE}Testing invalid arguments...${NC}"
    
    local output
    local exit_code
    
    # Test with no arguments
    output=$(run_change_site 2>&1) || exit_code=$?
    assert_exit_code 1 ${exit_code:-0} "No arguments should exit with code 1"
    
    # Test with one argument
    output=$(run_change_site "192.168" 2>&1) || exit_code=$?
    assert_exit_code 1 ${exit_code:-0} "One argument should exit with code 1"
    
    # Test with invalid option
    output=$(run_change_site "--invalid-option" "192.168" "172.23" 2>&1) || exit_code=$?
    assert_exit_code 1 ${exit_code:-0} "Invalid option should exit with code 1"
}

# =============================================================================
# VALIDATION TESTS
# =============================================================================

test_subnet_validation() {
    echo -e "\n${BLUE}Testing subnet validation...${NC}"
    
    local output
    local exit_code
    
    # Test invalid subnet format
    output=$(run_change_site "--dry-run" "invalid" "172.23" 2>&1) || exit_code=$?
    assert_exit_code 5 ${exit_code:-0} "Invalid subnet format should exit with code 5"
    
    # Test invalid first octet
    output=$(run_change_site "--dry-run" "300.168" "172.23" 2>&1) || exit_code=$?
    assert_exit_code 5 ${exit_code:-0} "Invalid first octet should exit with code 5"
    
    # Test invalid second octet
    output=$(run_change_site "--dry-run" "192.300" "172.23" 2>&1) || exit_code=$?
    assert_exit_code 5 ${exit_code:-0} "Invalid second octet should exit with code 5"
    
    # Test identical subnets
    output=$(run_change_site "--dry-run" "192.168" "192.168" 2>&1) || exit_code=$?
    assert_exit_code 5 ${exit_code:-0} "Identical subnets should exit with code 5"
}

test_valid_subnet_formats() {
    echo -e "\n${BLUE}Testing valid subnet formats...${NC}"
    
    local output
    local exit_code
    
    # Test valid subnet format (dry run to avoid actual changes)
    output=$(run_change_site "--dry-run" "192.168" "172.23" 2>&1) || exit_code=$?
    assert_exit_code 0 ${exit_code:-0} "Valid subnets should not fail validation"
    assert_contains "$output" "DRY RUN MODE" "Dry run should be indicated"
}

# =============================================================================
# DRY RUN TESTS
# =============================================================================

test_dry_run_mode() {
    echo -e "\n${BLUE}Testing dry run mode...${NC}"
    
    local output
    local exit_code
    
    output=$(run_change_site "--dry-run" "192.168" "172.23" 2>&1) || exit_code=$?
    
    assert_exit_code 0 ${exit_code:-0} "Dry run should complete successfully"
    assert_contains "$output" "DRY RUN MODE" "Should indicate dry run mode"
    assert_contains "$output" "no changes were applied" "Should indicate no changes applied"
}

# =============================================================================
# BACKUP FUNCTIONALITY TESTS
# =============================================================================

test_backup_option() {
    echo -e "\n${BLUE}Testing backup option...${NC}"
    
    local output
    local exit_code
    
    output=$(run_change_site "--dry-run" "--backup" "192.168" "172.23" 2>&1) || exit_code=$?
    
    assert_exit_code 0 ${exit_code:-0} "Backup option should not cause errors"
    assert_contains "$output" "DRY RUN MODE" "Should still be in dry run mode"
}

# =============================================================================
# SCRIPT STRUCTURE TESTS
# =============================================================================

test_script_syntax() {
    echo -e "\n${BLUE}Testing script syntax...${NC}"
    
    local output
    local exit_code
    
    # Test bash syntax
    output=$(bash -n "$CHANGE_SITE_SCRIPT" 2>&1) || exit_code=$?
    assert_exit_code 0 ${exit_code:-0} "Script should have valid bash syntax"
}

test_script_executable() {
    echo -e "\n${BLUE}Testing script executable...${NC}"
    
    if [[ -x "$CHANGE_SITE_SCRIPT" ]]; then
        echo -e "${GREEN}✓${NC} Script is executable"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Script is not executable"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# =============================================================================
# FUNCTION EXTRACTION TESTS
# =============================================================================

test_function_definitions() {
    echo -e "\n${BLUE}Testing function definitions...${NC}"
    
    local functions=(
        "log_info"
        "log_error" 
        "validate_subnet_format"
        "check_networkmanager"
        "update_nm_connections"
        "update_hosts_file"
        "backup_file"
    )
    
    for func in "${functions[@]}"; do
        if grep -q "^${func}()" "$CHANGE_SITE_SCRIPT"; then
            echo -e "${GREEN}✓${NC} Function $func is defined"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗${NC} Function $func is not defined"
            ((TESTS_FAILED++))
        fi
        ((TESTS_RUN++))
    done
}

# =============================================================================
# SECURITY TESTS
# =============================================================================

test_security_practices() {
    echo -e "\n${BLUE}Testing security practices...${NC}"
    
    # Test for proper quoting
    local unquoted_vars
    unquoted_vars=$(grep -n '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$CHANGE_SITE_SCRIPT" | grep -v '^\s*#' | wc -l)
    
    if [[ "$unquoted_vars" -lt 10 ]]; then  # Allow some unquoted variables in specific contexts
        echo -e "${GREEN}✓${NC} Good variable quoting practices"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}!${NC} Many unquoted variables found ($unquoted_vars)"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    # Test for set -e usage
    if grep -q "set -euo pipefail" "$CHANGE_SITE_SCRIPT"; then
        echo -e "${GREEN}✓${NC} Proper error handling with set -euo pipefail"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Missing set -euo pipefail"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# =============================================================================
# COMPATIBILITY TESTS
# =============================================================================

test_rhel_compatibility() {
    echo -e "\n${BLUE}Testing RHEL compatibility...${NC}"
    
    # Test for bash version compatibility
    local bash_version
    bash_version=$(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+')
    local major_version=${bash_version%%.*}
    
    if [[ "$major_version" -ge 4 ]]; then
        echo -e "${GREEN}✓${NC} Bash version $bash_version is compatible with RHEL 8+"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} Bash version $bash_version may not be compatible"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    # Test for RHEL-specific commands
    local rhel_commands=("nmcli" "systemctl")
    for cmd in "${rhel_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Command $cmd is available"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}!${NC} Command $cmd is not available (may not be on RHEL system)"
            # Don't count as failure since we might not be on RHEL
        fi
        ((TESTS_RUN++))
    done
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
    
    # Run all test categories
    test_script_syntax
    test_script_executable
    test_help_option
    test_version_option
    test_invalid_arguments
    test_subnet_validation
    test_valid_subnet_formats
    test_dry_run_mode
    test_backup_option
    test_function_definitions
    test_security_practices
    test_rhel_compatibility
    
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