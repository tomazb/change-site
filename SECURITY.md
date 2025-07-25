# Security Policy

## Supported Versions

We actively support the following versions of change-site with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability in change-site, please report it responsibly.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please use one of the following methods:

1. **GitHub Security Advisories** (Preferred)
   - Go to https://github.com/tomazb/change-site/security/advisories
   - Click "Report a vulnerability"
   - Fill out the form with details

2. **Email** (Alternative)
   - Send an email to: [security contact to be added]
   - Include "SECURITY" in the subject line
   - Provide detailed information about the vulnerability

### What to Include

When reporting a vulnerability, please include:

- **Description**: Clear description of the vulnerability
- **Impact**: What could an attacker accomplish?
- **Reproduction**: Step-by-step instructions to reproduce
- **Environment**: OS, version, configuration details
- **Proof of Concept**: If applicable, include PoC code
- **Suggested Fix**: If you have ideas for remediation

### Example Report

```
Subject: SECURITY - Command Injection in change-site.sh

Description:
The change-site.sh script is vulnerable to command injection through
the subnet parameter when used with specific shell metacharacters.

Impact:
An attacker with the ability to control subnet parameters could execute
arbitrary commands with root privileges.

Reproduction:
1. Run: sudo ./change-site.sh "192.168; rm -rf /" "172.23"
2. Observe command injection execution

Environment:
- OS: RHEL 9.2
- change-site version: v1.1.0
- Bash version: 5.1.8

Suggested Fix:
Implement proper input validation and sanitization for subnet parameters.
```

## Response Process

### Timeline

- **Acknowledgment**: Within 48 hours of report
- **Initial Assessment**: Within 5 business days
- **Status Update**: Weekly updates during investigation
- **Resolution**: Target 30 days for critical issues, 90 days for others

### Our Commitment

When you report a vulnerability, we commit to:

1. **Acknowledge** your report promptly
2. **Investigate** the issue thoroughly
3. **Keep you informed** of our progress
4. **Credit you** appropriately (if desired)
5. **Coordinate disclosure** responsibly

### Severity Levels

We classify vulnerabilities using the following severity levels:

#### Critical
- Remote code execution as root
- Complete system compromise
- Data destruction or corruption

#### High
- Privilege escalation
- Authentication bypass
- Sensitive data exposure

#### Medium
- Local privilege escalation
- Information disclosure
- Denial of service

#### Low
- Minor information leaks
- Configuration issues
- Non-security bugs with security implications

## Security Best Practices

### For Users

1. **Keep Updated**: Always use the latest version
2. **Secure Configuration**: Follow security guidelines in documentation
3. **Principle of Least Privilege**: Run with minimal required permissions
4. **Regular Audits**: Review configurations and logs regularly
5. **Backup Strategy**: Maintain secure backups before changes

### For Developers

1. **Input Validation**: Validate all user inputs
2. **Output Encoding**: Properly encode outputs
3. **Secure Defaults**: Use secure configuration defaults
4. **Error Handling**: Don't expose sensitive information in errors
5. **Code Review**: All code changes require security review

## Known Security Considerations

### Current Security Features

- **Input Validation**: Subnet format validation
- **Privilege Separation**: Requires explicit root privileges
- **Secure Temp Files**: Temporary files created with 600 permissions
- **Backup Encryption**: Backup files secured with appropriate permissions
- **Audit Logging**: All operations logged for audit trails

### Potential Risk Areas

- **Root Privileges**: Script requires root access for network changes
- **Configuration Files**: May contain sensitive network information
- **Log Files**: Could contain network topology information
- **Backup Files**: Network configuration backups need protection

### Mitigation Strategies

1. **Access Control**: Limit who can execute the script
2. **Configuration Security**: Secure configuration file permissions
3. **Log Management**: Implement log rotation and secure storage
4. **Network Segmentation**: Limit network access where possible
5. **Monitoring**: Implement monitoring for unauthorized usage

## Security Testing

### Automated Security Testing

Our CI/CD pipeline includes:

- **Static Analysis**: Shellcheck security warnings
- **Vulnerability Scanning**: Trivy security scans
- **Dependency Checking**: Regular dependency updates
- **Permission Auditing**: File permission validation

### Manual Security Testing

We regularly perform:

- **Code Reviews**: Security-focused code reviews
- **Penetration Testing**: Simulated attack scenarios
- **Configuration Audits**: Security configuration reviews
- **Access Control Testing**: Permission and privilege testing

## Incident Response

### In Case of Security Incident

1. **Immediate Response**
   - Assess the scope and impact
   - Contain the incident
   - Preserve evidence

2. **Investigation**
   - Analyze logs and system state
   - Identify root cause
   - Document findings

3. **Remediation**
   - Apply security patches
   - Update configurations
   - Verify fixes

4. **Communication**
   - Notify affected users
   - Provide remediation guidance
   - Update security documentation

5. **Post-Incident**
   - Conduct lessons learned review
   - Update security procedures
   - Improve detection capabilities

## Security Updates

### Update Notifications

Security updates are communicated through:

- **GitHub Security Advisories**: Primary notification method
- **Release Notes**: Detailed in release documentation
- **GitHub Releases**: Tagged with security labels
- **Documentation**: Updated security guidelines

### Update Process

1. **Assessment**: Evaluate security impact
2. **Development**: Create and test security fix
3. **Testing**: Comprehensive security testing
4. **Release**: Coordinated security release
5. **Notification**: Inform users of security update

## Contact Information

### Security Team

- **Primary Contact**: [To be added]
- **Backup Contact**: [To be added]
- **Response Time**: 48 hours maximum

### Reporting Channels

- **GitHub Security**: https://github.com/tomazb/change-site/security
- **Email**: [To be added]
- **PGP Key**: [To be added if needed]

## Acknowledgments

We appreciate the security research community and thank all researchers who responsibly disclose vulnerabilities to help improve the security of change-site.

### Hall of Fame

Security researchers who have helped improve change-site:

- [Future contributors will be listed here]

## Legal

### Responsible Disclosure

We support responsible disclosure and will not pursue legal action against researchers who:

- Follow our reporting guidelines
- Do not access or modify data beyond what's necessary to demonstrate the vulnerability
- Do not perform testing on systems they don't own
- Do not publicly disclose vulnerabilities before coordinated disclosure

### Bug Bounty

Currently, we do not offer a formal bug bounty program, but we greatly appreciate security research contributions and will acknowledge researchers appropriately.

---

**Last Updated**: [Date to be updated]
**Version**: 1.0