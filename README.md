# change-site

A robust script to switch between network sites by replacing one subnet with another in:
- Network Manager configuration (using nmcli)
- /etc/hosts entries
- Optionally Pacemaker cluster configuration

## Problem Statement

Imagine that your first site is on 192.168.something and the other location is on 172.23.something. You want to keep the local addressing (the "something" part) and just change the site by modifying Network Manager configuration, /etc/hosts and optionally also the Pacemaker.

## Features

### Core Functionality
- Automatically modifies NetworkManager connections using nmcli commands
- Updates IP addresses, gateways, DNS servers, and routes while preserving host portions
- Updates /etc/hosts entries matching the source subnet
- Optional Pacemaker configuration updates
- Comprehensive dry-run mode with mock data for safe testing
- Creates secure backups of modified files and configurations

### Enhanced Capabilities
- **Structured Logging**: Multi-level logging (DEBUG, INFO, SUCCESS, WARNING, ERROR) with timestamps
- **Robust Error Handling**: Comprehensive error handling with proper exit codes and cleanup
- **Security Enhancements**: Secure temporary file creation with proper permissions (600)
- **Signal Handling**: Graceful shutdown and cleanup on interruption
- **Input Validation**: Enhanced subnet validation with comprehensive IPv4 checking
- **Modular Design**: Well-structured code with focused functions for maintainability

### Compatibility
- Designed to work on RHEL 8, RHEL 9, and RHEL 10
- Compatible with bash 4.4+ (RHEL 8) through bash 5.2+ (RHEL 10)
- Uses only features available across all target RHEL versions
- Color-coded output for better readability (auto-detects terminal support)

## Requirements

- Bash shell (version 4.4 or higher)
- Root privileges (when not using dry-run mode)
- NetworkManager with nmcli command
- Pacemaker cluster software (optional, only needed if using the Pacemaker update feature)

## Installation

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x change-site.sh
   ```

## Usage

```bash
./change-site.sh [options] <from_subnet> <to_subnet>
```

### Arguments

- `<from_subnet>` - Source subnet (e.g., 192.168)
- `<to_subnet>` - Destination subnet (e.g., 172.23)

### Options

- `-h, --help` - Show help message with examples
- `-v, --version` - Show version information
- `-p, --pacemaker` - Also update Pacemaker configuration
- `-n, --dry-run` - Show changes without applying them (safe testing mode)
- `-b, --backup` - Create backups of modified files
- `--verbose` - Enable verbose logging for debugging
- `--config FILE` - Use configuration file (future feature)

### Examples

**Preview changes (recommended first step):**
```bash
./change-site.sh -n 192.168 172.23
```

**Switch from 192.168.x.x to 172.23.x.x with backups:**
```bash
sudo ./change-site.sh -b 192.168 172.23
```

**Update all configurations including Pacemaker with verbose output:**
```bash
sudo ./change-site.sh -p -b --verbose 192.168 172.23
```

**Test with verbose dry-run mode:**
```bash
./change-site.sh --verbose --dry-run 192.168 172.23
```

## How it Works

The script performs the following steps:

1. **Argument Parsing**: Validates command-line arguments and options
2. **Input Validation**: Comprehensive subnet format validation and range checking
3. **Dependency Checking**: Verifies required tools and services (skipped in dry-run mode)
4. **Backup Creation**: Creates secure backups of files and NetworkManager connections
5. **NetworkManager Updates**: 
   - Finds connections with matching subnet addresses
   - Updates IPv4 addresses, gateways, DNS servers, and routes
   - Preserves the last two octets of IP addresses
   - Restarts NetworkManager and re-applies connections
6. **Hosts File Updates**: Updates /etc/hosts entries matching the source subnet
7. **Pacemaker Updates**: Optionally updates Pacemaker cluster configuration
8. **Cleanup**: Removes temporary files and performs graceful shutdown

## Exit Codes

The script uses standardized exit codes for better integration with automation tools:

- `0` - Success
- `1` - Invalid arguments
- `2` - Permission denied
- `3` - Missing dependencies
- `4` - Operation failed
- `5` - Validation failed

## Logging

The script provides comprehensive logging with multiple levels:

- **DEBUG**: Detailed execution information (use `--verbose`)
- **INFO**: General information about operations
- **SUCCESS**: Confirmation of successful operations
- **WARNING**: Non-fatal issues that should be noted
- **ERROR**: Fatal errors that prevent operation

Logs include timestamps and are written to `/var/log/change-site.log` when running with appropriate permissions.

## Security Considerations

### Best Practices
- Always use the dry-run mode first to verify changes before applying them
- Create backups with the `-b` option before making changes
- Review the verbose output to understand what changes will be made
- Test in a non-production environment first

### Security Features
- Requires root privileges only for actual modifications (not dry-run)
- Creates temporary files with secure permissions (600)
- Validates all user inputs to prevent injection attacks
- Implements proper cleanup on exit or interruption
- Logs all operations for audit trails

### Backup Strategy
- NetworkManager connections are exported before modification
- Files are backed up with timestamps in `/var/backups/change-site/`
- Backup files have secure permissions (600)
- Failed operations preserve original configurations

## Testing

The project includes comprehensive testing infrastructure:

### Running Tests
```bash
# Run comprehensive test suite
./test-change-site.sh

# Run basic functionality tests
./simple-test.sh

# Test specific functionality with dry-run
./change-site.sh --verbose --dry-run 192.168 172.23
```

### Test Coverage
- Syntax validation
- Help and version options
- Argument validation
- Subnet format validation
- Dry-run functionality
- Error handling
- RHEL compatibility
- Security practices

## Troubleshooting

### Common Issues

**Permission Denied Errors:**
- Ensure you're running with `sudo` for actual changes
- Use dry-run mode (`-n`) to test without requiring root

**NetworkManager Not Found:**
- Install NetworkManager: `sudo dnf install NetworkManager`
- Ensure NetworkManager service is running: `sudo systemctl start NetworkManager`

**Backup Directory Issues:**
- Check disk space in `/var/backups/`
- Verify write permissions to backup directory

**Verbose Debugging:**
```bash
# Enable verbose output for detailed debugging
./change-site.sh --verbose --dry-run 192.168 172.23
```

## Development

### Code Structure
The refactored script follows best practices with:
- Modular function design (all functions under 50 lines)
- Comprehensive error handling and cleanup
- Secure temporary file handling
- Proper signal handling
- No problematic global variables
- Extensive input validation

### Contributing
1. Test changes with the comprehensive test suite
2. Ensure RHEL 8-10 compatibility
3. Follow the established coding patterns
4. Add appropriate logging and error handling
5. Update documentation for new features

## Version History

### v2.0.0 (Current)
- Complete refactoring with modular design
- Enhanced security and error handling
- Comprehensive dry-run mode with mock data
- Structured logging system
- RHEL 8-10 compatibility improvements
- Comprehensive test suite
- Signal handling and cleanup

### v1.0.0 (Legacy)
- Original monolithic script
- Basic functionality only
- Limited error handling

## License

This project is open source and available under the [MIT License](LICENSE).

## Support

For issues, questions, or contributions:
1. Check the troubleshooting section above
2. Run with `--verbose` flag for detailed debugging
3. Test with dry-run mode first
4. Review the comprehensive test suite for examples