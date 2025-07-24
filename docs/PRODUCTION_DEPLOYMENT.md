# Production Deployment Guide

This guide provides comprehensive instructions for deploying change-site in production environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [Configuration](#configuration)
- [Security Considerations](#security-considerations)
- [Monitoring Setup](#monitoring-setup)
- [Backup and Recovery](#backup-and-recovery)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## Prerequisites

### System Requirements

#### Minimum Requirements
- **OS**: RHEL 8/9/10, CentOS 8/9, Rocky Linux 8/9, AlmaLinux 8/9
- **Memory**: 512MB RAM minimum, 1GB recommended
- **Storage**: 100MB free space for installation, 1GB for logs and backups
- **Network**: Administrative access to NetworkManager

#### Software Dependencies
- **Bash**: Version 4.4 or higher
- **NetworkManager**: Active and configured
- **Root Access**: Required for network configuration changes
- **Optional**: Pacemaker (if cluster configuration management needed)

### Network Environment
- Existing NetworkManager configuration
- Documented current network topology
- Change windows for network modifications
- Rollback procedures defined

## Installation Methods

### Method 1: GitHub Release (Recommended)

```bash
# Download latest release
cd /opt
wget https://github.com/tomazb/change-site/releases/latest/download/change-site-*.tar.gz

# Verify checksum
wget https://github.com/tomazb/change-site/releases/latest/download/checksums.txt
sha256sum -c checksums.txt

# Extract and install
tar -xzf change-site-*.tar.gz
cd change-site/
chmod +x change-site.sh monitoring-dashboard.sh debug-config.sh

# Create symlinks for system-wide access
ln -sf /opt/change-site/change-site.sh /usr/local/bin/change-site
ln -sf /opt/change-site/monitoring-dashboard.sh /usr/local/bin/change-site-monitor
```

### Method 2: Git Clone

```bash
# Clone repository
cd /opt
git clone https://github.com/tomazb/change-site.git
cd change-site/

# Checkout stable version
git checkout v1.1.0

# Make scripts executable
chmod +x *.sh

# Create symlinks
ln -sf /opt/change-site/change-site.sh /usr/local/bin/change-site
ln -sf /opt/change-site/monitoring-dashboard.sh /usr/local/bin/change-site-monitor
```

### Method 3: Package Installation (Future)

```bash
# RHEL/CentOS (when available)
dnf install change-site

# Ubuntu/Debian (when available)
apt install change-site
```

## Configuration

### Basic Configuration

#### 1. Create Configuration File

```bash
# Copy example configuration
cp /opt/change-site/change-site.conf.example /etc/change-site.conf

# Edit configuration
vim /etc/change-site.conf
```

#### 2. Essential Configuration Options

```bash
# /etc/change-site.conf

# Logging configuration
CONFIG_LOG_LEVEL="INFO"
CONFIG_LOG_FILE="/var/log/change-site.log"
CONFIG_STRUCTURED_LOGGING="true"

# Backup configuration
CONFIG_BACKUP_DIR="/var/backups/change-site"
CONFIG_BACKUP_RETENTION_DAYS="30"

# Monitoring configuration
CONFIG_ENABLE_MONITORING="true"
CONFIG_ENABLE_ALERTS="true"
CONFIG_ALERT_EMAIL="admin@company.com"

# Security configuration
CONFIG_REQUIRE_CONFIRMATION="true"
CONFIG_DRY_RUN_DEFAULT="false"

# Pacemaker configuration (if applicable)
CONFIG_PACEMAKER_ENABLED="false"
CONFIG_PACEMAKER_CIB_FILE="/var/lib/pacemaker/cib/cib.xml"
```

### Advanced Configuration

#### Environment-Specific Profiles

```bash
# Create environment profiles
mkdir -p /etc/change-site/profiles

# Production profile
cat > /etc/change-site/profiles/production.conf << 'EOF'
CONFIG_LOG_LEVEL="INFO"
CONFIG_BACKUP_RETENTION_DAYS="90"
CONFIG_REQUIRE_CONFIRMATION="true"
CONFIG_ENABLE_ALERTS="true"
CONFIG_ALERT_EMAIL="production-alerts@company.com"
EOF

# Development profile
cat > /etc/change-site/profiles/development.conf << 'EOF'
CONFIG_LOG_LEVEL="DEBUG"
CONFIG_BACKUP_RETENTION_DAYS="7"
CONFIG_REQUIRE_CONFIRMATION="false"
CONFIG_ENABLE_ALERTS="false"
EOF

# Usage with profiles
change-site --config /etc/change-site/profiles/production.conf 192.168 172.23
```

#### Network Validation Configuration

```bash
# Add to main configuration
CONFIG_VALIDATE_CONNECTIVITY="true"
CONFIG_VALIDATION_HOSTS="8.8.8.8,1.1.1.1"
CONFIG_VALIDATION_TIMEOUT="10"
CONFIG_ROLLBACK_ON_FAILURE="true"
```

## Security Considerations

### File Permissions

```bash
# Set secure permissions
chmod 600 /etc/change-site.conf
chmod 600 /etc/change-site/profiles/*.conf
chmod 700 /var/log/change-site.log
chmod 700 /var/backups/change-site/

# Set ownership
chown root:root /etc/change-site.conf
chown -R root:root /etc/change-site/
chown root:root /var/log/change-site.log
chown -R root:root /var/backups/change-site/
```

### SELinux Configuration

```bash
# Check SELinux status
getenforce

# If SELinux is enforcing, create custom policy
# Create SELinux policy file
cat > change-site.te << 'EOF'
module change-site 1.0;

require {
    type admin_home_t;
    type NetworkManager_t;
    type etc_t;
    class file { read write execute };
    class dir { search };
}

# Allow change-site to read configuration
allow admin_home_t etc_t:file { read };
allow admin_home_t etc_t:dir { search };

# Allow NetworkManager interaction
allow admin_home_t NetworkManager_t:file { read write };
EOF

# Compile and install policy
checkmodule -M -m -o change-site.mod change-site.te
semodule_package -o change-site.pp -m change-site.mod
semodule -i change-site.pp
```

### Sudo Configuration

```bash
# Create sudoers file for change-site
cat > /etc/sudoers.d/change-site << 'EOF'
# Allow network administrators to run change-site
%netadmin ALL=(root) NOPASSWD: /usr/local/bin/change-site
%netadmin ALL=(root) NOPASSWD: /usr/local/bin/change-site-monitor

# Audit logging
Defaults!/usr/local/bin/change-site log_input,log_output
Defaults!/usr/local/bin/change-site-monitor log_input,log_output
EOF

chmod 440 /etc/sudoers.d/change-site
```

## Monitoring Setup

### Log Rotation

```bash
# Create logrotate configuration
cat > /etc/logrotate.d/change-site << 'EOF'
/var/log/change-site.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
    postrotate
        /bin/systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/var/log/change-site-metrics.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 600 root root
}
EOF
```

### Systemd Service (Optional)

```bash
# Create systemd service for monitoring
cat > /etc/systemd/system/change-site-monitor.service << 'EOF'
[Unit]
Description=Change-Site Monitoring Dashboard
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/change-site-monitor --daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable change-site-monitor.service
systemctl start change-site-monitor.service
```

### External Monitoring Integration

#### Prometheus Integration

```bash
# Create metrics endpoint
cat > /opt/change-site/prometheus-exporter.sh << 'EOF'
#!/bin/bash
# Simple Prometheus metrics exporter for change-site

METRICS_FILE="/var/log/change-site-metrics.log"
OUTPUT_FILE="/var/lib/prometheus/node-exporter/change-site.prom"

# Generate metrics
{
    echo "# HELP change_site_operations_total Total number of operations"
    echo "# TYPE change_site_operations_total counter"
    grep -c "OPERATION_START" "$METRICS_FILE" | \
        awk '{print "change_site_operations_total " $1}'
    
    echo "# HELP change_site_errors_total Total number of errors"
    echo "# TYPE change_site_errors_total counter"
    grep -c "ERROR" "$METRICS_FILE" | \
        awk '{print "change_site_errors_total " $1}'
} > "$OUTPUT_FILE"
EOF

chmod +x /opt/change-site/prometheus-exporter.sh

# Add to cron
echo "*/5 * * * * root /opt/change-site/prometheus-exporter.sh" >> /etc/crontab
```

## Backup and Recovery

### Automated Backup Strategy

```bash
# Create backup script
cat > /opt/change-site/backup-script.sh << 'EOF'
#!/bin/bash
# Automated backup script for change-site

BACKUP_DIR="/var/backups/change-site"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup
mkdir -p "$BACKUP_DIR/$DATE"

# Backup NetworkManager connections
nmcli connection show | tail -n +2 | while read -r line; do
    uuid=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | awk '{print $1}')
    nmcli connection export "$uuid" > "$BACKUP_DIR/$DATE/nm_${name}_${uuid}.nmconnection"
done

# Backup configuration files
cp /etc/change-site.conf "$BACKUP_DIR/$DATE/"
cp -r /etc/change-site/ "$BACKUP_DIR/$DATE/"

# Backup hosts file
cp /etc/hosts "$BACKUP_DIR/$DATE/"

# Create manifest
{
    echo "Backup created: $(date)"
    echo "System: $(hostname)"
    echo "Version: $(change-site --version)"
    echo "Files:"
    find "$BACKUP_DIR/$DATE" -type f -exec ls -la {} \;
} > "$BACKUP_DIR/$DATE/manifest.txt"

# Cleanup old backups
find "$BACKUP_DIR" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

echo "Backup completed: $BACKUP_DIR/$DATE"
EOF

chmod +x /opt/change-site/backup-script.sh

# Schedule daily backups
echo "0 2 * * * root /opt/change-site/backup-script.sh" >> /etc/crontab
```

### Recovery Procedures

#### Full System Recovery

```bash
# Recovery script
cat > /opt/change-site/recovery-script.sh << 'EOF'
#!/bin/bash
# Recovery script for change-site

BACKUP_DIR="/var/backups/change-site"
RECOVERY_DATE="$1"

if [[ -z "$RECOVERY_DATE" ]]; then
    echo "Usage: $0 <backup_date>"
    echo "Available backups:"
    ls -la "$BACKUP_DIR"
    exit 1
fi

BACKUP_PATH="$BACKUP_DIR/$RECOVERY_DATE"

if [[ ! -d "$BACKUP_PATH" ]]; then
    echo "Backup not found: $BACKUP_PATH"
    exit 1
fi

echo "Recovering from backup: $RECOVERY_DATE"

# Stop NetworkManager
systemctl stop NetworkManager

# Restore NetworkManager connections
for file in "$BACKUP_PATH"/nm_*.nmconnection; do
    if [[ -f "$file" ]]; then
        nmcli connection import type generic file "$file"
    fi
done

# Restore configuration
cp "$BACKUP_PATH/change-site.conf" /etc/
cp -r "$BACKUP_PATH/change-site" /etc/

# Restore hosts file
cp "$BACKUP_PATH/hosts" /etc/

# Start NetworkManager
systemctl start NetworkManager

echo "Recovery completed from $RECOVERY_DATE"
echo "Please verify network connectivity"
EOF

chmod +x /opt/change-site/recovery-script.sh
```

## Troubleshooting

### Common Production Issues

#### Issue 1: Permission Denied
```bash
# Symptoms
change-site: Permission denied

# Solution
sudo chown root:root /usr/local/bin/change-site
sudo chmod 755 /usr/local/bin/change-site
```

#### Issue 2: NetworkManager Not Responding
```bash
# Symptoms
Error: NetworkManager is not running

# Diagnosis
systemctl status NetworkManager
journalctl -u NetworkManager -n 50

# Solution
systemctl restart NetworkManager
```

#### Issue 3: Configuration File Not Found
```bash
# Symptoms
Warning: Configuration file not found

# Solution
cp /opt/change-site/change-site.conf.example /etc/change-site.conf
vim /etc/change-site.conf
```

### Diagnostic Commands

```bash
# System health check
change-site --health-check

# Verbose dry run
change-site --verbose --dry-run 192.168 172.23

# Monitor dashboard
change-site-monitor

# Check logs
tail -f /var/log/change-site.log
journalctl -f -u change-site-monitor
```

## Maintenance

### Regular Maintenance Tasks

#### Weekly Tasks
```bash
# Check log file sizes
du -sh /var/log/change-site*

# Verify backup integrity
/opt/change-site/backup-script.sh

# Update system
dnf update -y
```

#### Monthly Tasks
```bash
# Review configuration
change-site --config-check

# Performance analysis
grep "PERFORMANCE" /var/log/change-site-metrics.log | tail -100

# Security audit
find /etc/change-site -type f -not -perm 600 -exec ls -la {} \;
```

#### Quarterly Tasks
```bash
# Update change-site
cd /opt/change-site
git fetch --tags
git checkout $(git describe --tags $(git rev-list --tags --max-count=1))

# Review and update documentation
vim /etc/change-site.conf

# Disaster recovery test
/opt/change-site/recovery-script.sh $(ls /var/backups/change-site | tail -1)
```

### Performance Optimization

#### Network Interface Optimization
```bash
# Add to configuration
CONFIG_PARALLEL_PROCESSING="true"
CONFIG_CONNECTION_TIMEOUT="30"
CONFIG_MAX_RETRIES="3"
```

#### Log Management
```bash
# Optimize logging for high-volume environments
CONFIG_LOG_LEVEL="WARNING"
CONFIG_STRUCTURED_LOGGING="false"
CONFIG_METRICS_SAMPLING="10"  # Log every 10th operation
```

## Production Checklist

### Pre-Deployment
- [ ] System requirements verified
- [ ] Dependencies installed
- [ ] Configuration file created and secured
- [ ] Backup procedures tested
- [ ] Monitoring configured
- [ ] Security policies applied
- [ ] Documentation updated

### Post-Deployment
- [ ] Functionality tested with dry-run
- [ ] Monitoring dashboard accessible
- [ ] Log rotation configured
- [ ] Backup verification completed
- [ ] Recovery procedures tested
- [ ] Team training completed
- [ ] Documentation distributed

### Ongoing Operations
- [ ] Regular backup verification
- [ ] Log monitoring and analysis
- [ ] Performance metrics review
- [ ] Security updates applied
- [ ] Configuration drift detection
- [ ] Disaster recovery testing
- [ ] Team knowledge updates

## Support and Escalation

### Internal Support
1. Check troubleshooting section
2. Review logs and monitoring
3. Consult documentation
4. Test with dry-run mode

### External Support
1. GitHub Issues: https://github.com/tomazb/change-site/issues
2. Documentation: https://github.com/tomazb/change-site/docs
3. Community: GitHub Discussions

### Emergency Procedures
1. Stop all change-site operations
2. Restore from latest backup
3. Verify network connectivity
4. Document incident
5. Update procedures based on lessons learned