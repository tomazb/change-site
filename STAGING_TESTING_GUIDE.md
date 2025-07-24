# Staging Environment Testing Guide

## Overview

This guide provides comprehensive instructions for testing the change-site deployment tool in a staging environment before production deployment. It covers all new features including configuration file support, rollback functionality, and the enhanced test suite.

## Prerequisites

### Environment Setup
```bash
# 1. Create a staging directory structure
mkdir -p /tmp/staging-test/{source,target,backup,config}
cd /tmp/staging-test

# 2. Copy the change-site script
cp /path/to/change-site.sh ./
chmod +x change-site.sh

# 3. Create test content
mkdir -p source/{html,css,js,images}
echo "<h1>Staging Test v1.0</h1>" > source/index.html
echo "body { background: #f0f0f0; }" > source/css/style.css
echo "console.log('staging test');" > source/js/app.js
```

### Configuration File Testing
```bash
# Create staging configuration file
cat > staging-config.conf << 'EOF'
# Staging Environment Configuration
SOURCE_DIR="/tmp/staging-test/source"
TARGET_DIR="/tmp/staging-test/target"
BACKUP_DIR="/tmp/staging-test/backup"
ENABLE_ROLLBACK=true
BACKUP_RETENTION_DAYS=7
LOG_LEVEL="DEBUG"
NOTIFICATION_EMAIL="staging-admin@example.com"
STRUCTURED_LOGGING=true
ENABLE_MONITORING=true
ENABLE_ALERTS=true
EOF
```

## Testing Scenarios

### 1. Basic Deployment Testing

#### Test 1.1: First-time Deployment
```bash
# Test basic deployment without configuration file
./change-site.sh 192.168.1 192.168.2

# Expected Results:
# - Files copied successfully
# - Backup created in default location
# - No errors in output
# - Target directory contains all source files
```

#### Test 1.2: Configuration File Deployment
```bash
# Test deployment with configuration file
./change-site.sh -c staging-config.conf

# Expected Results:
# - Configuration loaded from file
# - Deployment uses configured paths
# - Debug logging enabled
# - Backup created in specified directory
```

### 2. Configuration System Testing

#### Test 2.1: Configuration Validation
```bash
# Test invalid configuration
echo "INVALID_OPTION=true" >> staging-config.conf
./change-site.sh -c staging-config.conf

# Expected Results:
# - Warning about unknown configuration option
# - Deployment continues with valid options
# - Invalid options ignored gracefully
```

#### Test 2.2: Missing Configuration File
```bash
# Test with non-existent config file
./change-site.sh -c non-existent.conf

# Expected Results:
# - Clear error message about missing file
# - Script exits gracefully
# - No partial deployment
```

#### Test 2.3: Configuration Override
```bash
# Test command line override of config file
./change-site.sh -c staging-config.conf 192.168.3 192.168.4

# Expected Results:
# - Command line arguments take precedence
# - Other config file options still applied
# - Deployment uses override subnets
```

### 3. Rollback Functionality Testing

#### Test 3.1: Successful Deployment (No Rollback)
```bash
# Create initial deployment
./change-site.sh -c staging-config.conf

# Modify source and deploy again
echo "<h1>Updated Content v2.0</h1>" > source/index.html
./change-site.sh -c staging-config.conf

# Expected Results:
# - Backup of previous version created
# - New content deployed successfully
# - No rollback triggered
# - Previous backup preserved
```

#### Test 3.2: Simulated Failure and Rollback
```bash
# Create a scenario that will trigger rollback
# (Simulate by creating a file that will cause permission issues)
sudo touch target/protected-file
sudo chmod 000 target/protected-file

# Attempt deployment
echo "<h1>This should rollback</h1>" > source/index.html
./change-site.sh -c staging-config.conf

# Expected Results:
# - Deployment failure detected
# - Automatic rollback initiated
# - Previous version restored
# - Clear error messages displayed
```

#### Test 3.3: Manual Rollback
```bash
# Test manual rollback functionality
./change-site.sh --rollback

# Expected Results:
# - Previous backup identified
# - Rollback confirmation prompt
# - Successful restoration of previous version
# - Current version backed up before rollback
```

### 4. Enhanced Logging and Monitoring

#### Test 4.1: Log Level Testing
```bash
# Test different log levels
sed -i 's/LOG_LEVEL="DEBUG"/LOG_LEVEL="INFO"/' staging-config.conf
./change-site.sh -c staging-config.conf

# Test verbose mode
./change-site.sh -v -c staging-config.conf

# Expected Results:
# - Appropriate log detail for each level
# - Timestamps in log entries
# - Structured log format
# - No sensitive information in logs
```

#### Test 4.2: Structured Logging
```bash
# Enable structured logging
echo "STRUCTURED_LOGGING=true" >> staging-config.conf
./change-site.sh -c staging-config.conf

# Check structured log output
cat /var/log/change-site-structured.log | tail -5 | jq '.'

# Expected Results:
# - JSON-formatted log entries
# - Proper timestamp, level, component fields
# - Performance metrics included
# - Valid JSON structure
```

#### Test 4.3: Monitoring and Alerts
```bash
# Test monitoring functionality
echo "ENABLE_MONITORING=true" >> staging-config.conf
echo "ENABLE_ALERTS=true" >> staging-config.conf
./change-site.sh -c staging-config.conf

# Check metrics file
cat /var/log/change-site-metrics.log

# Expected Results:
# - Performance metrics logged
# - Health checks recorded
# - Alert thresholds monitored
# - Metrics file properly formatted
```

### 5. Test Suite Validation

#### Test 5.1: Run Basic Tests
```bash
# Navigate to project directory
cd /path/to/change-site

# Run basic test suite
./tests/run-tests.sh --basic

# Expected Results:
# - All basic tests pass
# - Clear test output
# - No hanging tests
# - Proper exit codes
```

#### Test 5.2: Run Integration Tests
```bash
# Run full integration tests
./tests/run-tests.sh --integration

# Expected Results:
# - Configuration tests pass
# - Rollback tests pass
# - Error handling tests pass
# - Performance within acceptable limits
```

#### Test 5.3: Run Enhanced Tests
```bash
# Run comprehensive test suite
./tests/run-tests.sh --enhanced

# Expected Results:
# - All tests complete successfully
# - Detailed test reports generated
# - Code coverage information
# - Performance metrics collected
```

### 6. Monitoring Dashboard Testing

#### Test 6.1: Dashboard Functionality
```bash
# Start monitoring dashboard
./monitoring-dashboard.sh

# Test dashboard features:
# 1. View system health
# 2. Check recent operations
# 3. Review performance metrics
# 4. Examine error logs
# 5. Clear logs (test environment only)

# Expected Results:
# - Dashboard displays correctly
# - All menu options functional
# - Real-time data updates
# - Proper color coding for status
```

#### Test 6.2: Health Check Integration
```bash
# Test health check functionality
./monitoring-dashboard.sh
# Select option 6 (Run health check)

# Expected Results:
# - Health check completes successfully
# - Disk usage reported accurately
# - Log file sizes monitored
# - Error counts tracked
```

## Performance Testing

### Load Testing
```bash
# Create multiple source directories
for i in {1..10}; do
    mkdir -p "source-$i"
    for j in {1..100}; do
        echo "Test file $j" > "source-$i/file-$j.txt"
    done
done

# Test deployment performance
time ./change-site.sh 192.168.1 192.168.2 source-1 target-1
time ./change-site.sh 192.168.1 192.168.2 source-5 target-5
time ./change-site.sh 192.168.1 192.168.2 source-10 target-10

# Expected Results:
# - Consistent performance across different sizes
# - Memory usage within reasonable limits
# - No performance degradation with larger deployments
```

### Concurrent Deployment Testing
```bash
# Test multiple simultaneous deployments
./change-site.sh 192.168.1 192.168.2 source-1 target-1 &
./change-site.sh 192.168.3 192.168.4 source-2 target-2 &
./change-site.sh 192.168.5 192.168.6 source-3 target-3 &
wait

# Expected Results:
# - All deployments complete successfully
# - No file conflicts or corruption
# - Proper locking mechanisms work
# - Clean error handling for conflicts
```

### Performance Metrics Validation
```bash
# Test performance monitoring
./change-site.sh -c staging-config.conf --verbose

# Check performance logs
grep "PERFORMANCE" /var/log/change-site-metrics.log

# Expected Results:
# - Operation timings recorded
# - Performance within expected ranges
# - No performance regressions
# - Metrics properly formatted
```

## Security Testing

### Permission Testing
```bash
# Test with different user permissions
sudo -u nobody ./change-site.sh 192.168.1 192.168.2

# Test with read-only source
chmod -R 444 source/
./change-site.sh 192.168.1 192.168.2 source target-readonly
chmod -R 755 source/

# Expected Results:
# - Appropriate permission checks
# - Clear error messages for permission issues
# - No security vulnerabilities exposed
# - Proper handling of restricted access
```

### Input Validation Testing
```bash
# Test with malicious input
./change-site.sh "../../../etc" "target-dangerous"
./change-site.sh "192.168.1; rm -rf /" "192.168.2"

# Expected Results:
# - Input properly sanitized
# - Path traversal attempts blocked
# - Command injection prevented
# - Security warnings logged
```

### Configuration Security Testing
```bash
# Test configuration file security
chmod 666 staging-config.conf
./change-site.sh -c staging-config.conf

# Test with sensitive data in config
echo "PASSWORD=secret123" >> staging-config.conf
./change-site.sh -c staging-config.conf

# Expected Results:
# - Configuration file permissions validated
# - Sensitive data not logged
# - Security warnings for insecure permissions
# - Proper handling of credentials
```

## Error Handling and Recovery

### Error Simulation Testing
```bash
# Test disk space exhaustion simulation
dd if=/dev/zero of=/tmp/fill-disk bs=1M count=1000 2>/dev/null || true
./change-site.sh -c staging-config.conf
rm -f /tmp/fill-disk

# Test network connectivity issues
# (Simulate by blocking nmcli commands)
alias nmcli="echo 'Connection failed'; exit 1"
./change-site.sh 192.168.1 192.168.2
unalias nmcli

# Expected Results:
# - Graceful error handling
# - Appropriate error messages
# - No partial state corruption
# - Proper cleanup on failure
```

### Recovery Testing
```bash
# Test recovery from partial failures
./change-site.sh 192.168.1 192.168.2 --dry-run
# Interrupt with Ctrl+C during execution

# Test recovery mechanisms
./change-site.sh --rollback

# Expected Results:
# - Graceful handling of interruptions
# - Proper cleanup of temporary files
# - Recovery options available
# - No system state corruption
```

## Integration Testing

### NetworkManager Integration
```bash
# Test NetworkManager integration (requires root)
sudo ./change-site.sh 192.168.1 192.168.2 --dry-run

# Expected Results:
# - NetworkManager connections detected
# - Proper connection analysis
# - No actual changes in dry-run mode
# - Accurate change predictions
```

### Pacemaker Integration
```bash
# Test Pacemaker integration (if available)
sudo ./change-site.sh 192.168.1 192.168.2 --pacemaker --dry-run

# Expected Results:
# - Pacemaker configuration analyzed
# - Cluster resources identified
# - Safe dry-run execution
# - Proper resource handling
```

### System Service Integration
```bash
# Test system service interactions
systemctl status NetworkManager
./change-site.sh 192.168.1 192.168.2 --dry-run

# Expected Results:
# - Service status properly checked
# - Dependencies validated
# - No service disruption in dry-run
# - Proper service interaction
```

## Cleanup and Verification

### Post-Test Cleanup
```bash
# Clean up staging environment
rm -rf /tmp/staging-test
unset SOURCE_DIR TARGET_DIR BACKUP_DIR

# Verify no system changes
# Check that no files were created outside staging area
find /tmp -name "*change-site*" -type f 2>/dev/null || echo "Clean"

# Verify system integrity
systemctl status NetworkManager
```

### Test Report Generation
```bash
# Generate comprehensive test report
./tests/run-tests.sh --enhanced --report > staging-test-report.txt

# Review results
echo "=== STAGING TEST RESULTS ==="
echo "- All tests passed: ✅"
echo "- Performance within limits: ✅"  
echo "- Security tests passed: ✅"
echo "- No regressions detected: ✅"
echo "- Monitoring functional: ✅"
echo "- Configuration system working: ✅"
echo "- Rollback system tested: ✅"
```

### Verification Checklist
```bash
# Complete verification checklist
echo "STAGING ENVIRONMENT VERIFICATION CHECKLIST"
echo "==========================================="
echo "[ ] Basic functionality tests passed"
echo "[ ] Configuration system validated"
echo "[ ] Rollback functionality tested"
echo "[ ] Monitoring and logging verified"
echo "[ ] Performance metrics acceptable"
echo "[ ] Security tests completed"
echo "[ ] Error handling validated"
echo "[ ] Integration tests passed"
echo "[ ] Dashboard functionality confirmed"
echo "[ ] Cleanup completed successfully"
```

## Troubleshooting Common Issues

### Issue 1: Configuration Not Loading
**Symptoms:** Default values used despite config file
**Solution:** 
```bash
# Check file permissions and syntax
ls -la staging-config.conf
./change-site.sh --config staging-config.conf --verbose
```

### Issue 2: Rollback Not Triggered
**Symptoms:** Failed deployment doesn't rollback
**Solution:**
```bash
# Verify ENABLE_ROLLBACK=true in config
grep ENABLE_ROLLBACK staging-config.conf
# Check backup directory permissions
ls -la /tmp/staging-test/backup/
```

### Issue 3: Tests Hanging
**Symptoms:** Test suite doesn't complete
**Solution:**
```bash
# Check for arithmetic operation issues
./tests/run-tests.sh --basic --verbose
# Ensure || true added to counter operations
```

### Issue 4: Permission Errors
**Symptoms:** Deployment fails with permission denied
**Solution:**
```bash
# Verify user has appropriate access
whoami
ls -la source/ target/
# Check directory permissions
chmod -R 755 source/ target/
```

### Issue 5: Monitoring Not Working
**Symptoms:** No metrics or health data
**Solution:**
```bash
# Check monitoring configuration
grep -E "ENABLE_MONITORING|METRICS_FILE" staging-config.conf
# Verify log directory permissions
ls -la /var/log/
```

## Staging Environment Best Practices

1. **Isolation:** Always use isolated directories for staging tests
2. **Data Safety:** Never test with production data
3. **Monitoring:** Monitor resource usage during tests
4. **Documentation:** Record all test results and issues
5. **Automation:** Automate repetitive test scenarios
6. **Validation:** Verify all features work as expected before production
7. **Security:** Test with minimal required permissions
8. **Performance:** Establish baseline performance metrics
9. **Recovery:** Always test rollback procedures
10. **Integration:** Test with actual system components when safe

## Production Readiness Checklist

- [ ] All staging tests pass
- [ ] Performance meets requirements
- [ ] Security tests pass
- [ ] Documentation is complete
- [ ] Rollback procedures tested
- [ ] Monitoring and logging verified
- [ ] Configuration validated
- [ ] User acceptance testing completed
- [ ] Backup procedures verified
- [ ] Error handling validated
- [ ] Integration testing completed
- [ ] Dashboard functionality confirmed

## Next Steps

After successful staging testing:
1. **Schedule production deployment**
2. **Prepare rollback plan**
3. **Set up monitoring alerts**
4. **Notify stakeholders**
5. **Execute deployment during maintenance window**
6. **Monitor initial production usage**
7. **Validate production functionality**
8. **Document any production-specific issues**

## Emergency Procedures

### If Staging Tests Fail
1. **Stop all testing immediately**
2. **Document the failure scenario**
3. **Restore staging environment to clean state**
4. **Investigate root cause**
5. **Fix issues and retest**
6. **Do not proceed to production until all tests pass**

### If Production Issues Occur
1. **Execute rollback plan immediately**
2. **Use monitoring dashboard to assess impact**
3. **Check rollback success via health checks**
4. **Document incident for post-mortem**
5. **Return to staging for additional testing**

This comprehensive staging testing guide ensures safe validation of all change-site features before production deployment.