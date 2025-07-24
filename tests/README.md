# Change-Site Test Suite

This directory contains comprehensive tests for the change-site.sh script, organized into multiple test suites covering different aspects of functionality.

## Test Structure

```
tests/
├── run-tests.sh                    # Main test runner
├── test-change-site.sh            # Basic functionality tests
├── test-integration.sh            # Integration tests
├── test-change-site-enhanced.sh   # Enhanced tests with mock environments
└── README.md                      # This file
```

## Test Suites

### 1. Basic Functionality Tests (`test-change-site.sh`)
- **Purpose**: Core functionality and syntax validation
- **Coverage**: 
  - Script syntax validation
  - Help and version options
  - Argument validation
  - Subnet format validation
  - Dry-run mode testing
  - Security practices verification
  - RHEL compatibility checks

### 2. Integration Tests (`test-integration.sh`)
- **Purpose**: End-to-end feature testing
- **Coverage**:
  - Configuration file loading
  - Profile-based configuration
  - Predefined subnet pairs
  - Operation ID generation
  - Rollback functionality
  - Multi-connection handling
  - Error condition testing
  - Performance benchmarking

### 3. Enhanced Tests (`test-change-site-enhanced.sh`)
- **Purpose**: Advanced testing with mock environments
- **Coverage**:
  - Mock NetworkManager environment
  - Multi-connection scenarios
  - Container compatibility
  - Memory usage testing
  - Performance metrics
  - Complex error conditions

## Running Tests

### Quick Start
```bash
# Run all tests
./tests/run-tests.sh

# Run specific test suite
./tests/run-tests.sh --basic
./tests/run-tests.sh --integration
./tests/run-tests.sh --enhanced
```

### Individual Test Execution
```bash
# Run basic tests only
./tests/test-change-site.sh

# Run integration tests only
./tests/test-integration.sh

# Run enhanced tests only
./tests/test-change-site-enhanced.sh
```

## Test Requirements

### System Requirements
- Bash 4.0 or higher
- `bc` calculator (for performance tests)
- Standard UNIX utilities (`grep`, `sed`, `awk`, `find`)

### Optional Requirements
- `nmcli` (NetworkManager CLI) - for real system testing
- `uuidgen` - for UUID generation (fallback available)
- `/usr/bin/time` - for memory usage testing
- Container runtime - for container compatibility testing

## Test Configuration

### Environment Variables
- `CHANGE_SITE_SCRIPT` - Path to the main script (auto-detected)
- `TEST_TEMP_DIR` - Temporary directory for test files
- `TEST_LOG` - Path to test log file

### Test Data
Tests create temporary configuration files and mock environments automatically. No manual setup is required.

## Test Output

### Success Indicators
- ✓ Green checkmarks indicate passed tests
- Test summaries show pass/fail counts
- Exit code 0 indicates all tests passed

### Failure Indicators
- ✗ Red X marks indicate failed tests
- Detailed error messages explain failures
- Exit code 1 indicates test failures

### Performance Metrics
- Integration and enhanced tests include performance measurements
- Timing information for key operations
- Memory usage tracking (when available)

## Debugging Tests

### Verbose Output
```bash
# Enable verbose mode for debugging
./tests/test-integration.sh --verbose

# Check test logs
tail -f /tmp/change-site-*-test.log
```

### Common Issues
1. **Permission Errors**: Ensure test scripts are executable
2. **Missing Dependencies**: Install required tools (`bc`, `nmcli`, etc.)
3. **Path Issues**: Tests automatically detect script location
4. **Temporary Files**: Tests clean up automatically on exit

## Adding New Tests

### Test Framework Functions
- `assert_equals(expected, actual, test_name)`
- `assert_contains(haystack, needle, test_name)`
- `assert_success(test_name, exit_code)`
- `assert_performance_threshold(metric, time, threshold, test_name)`

### Example Test Function
```bash
test_new_feature() {
    echo -e "\n${BLUE}Testing New Feature...${NC}"
    
    local output exit_code
    output=$("$CHANGE_SITE_SCRIPT" --new-option 2>&1) || exit_code=$?
    
    assert_success "New feature test" "${exit_code:-0}"
    assert_contains "$output" "expected_text" "Feature output validation"
}
```

## Test Coverage

### Current Coverage
- ✅ Configuration file support
- ✅ Rollback functionality  
- ✅ Error handling and validation
- ✅ Multi-connection scenarios
- ✅ Performance benchmarking
- ✅ Security practices
- ✅ RHEL compatibility

### Areas for Enhancement
- Network interface testing
- Pacemaker integration testing
- Large-scale performance testing
- Stress testing with many connections

## Continuous Integration

The test suite is designed to work in CI/CD environments:
- Non-interactive execution
- Clear exit codes
- Structured output
- Minimal external dependencies
- Container-friendly design

## Contributing

When adding new features to change-site.sh:
1. Add corresponding tests to appropriate test suite
2. Update test documentation
3. Ensure all tests pass before committing
4. Consider adding performance benchmarks for new features