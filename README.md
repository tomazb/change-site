# change-site

A script to switch between network sites by replacing one subnet with another in:
- Network Manager configuration (using nmcli)
- /etc/hosts entries
- Optionally Pacemaker cluster configuration

## Problem Statement

Imagine that your first site is on 192.168.something and the other location is on 172.23.something. You want to keep the local addressing (the "something" part) and just change the site by modifying Network Manager configuration, /etc/hosts and optionally also the Pacemaker.

## Features

- Automatically modifies NetworkManager connections using nmcli commands (works on RHEL 8.8 and similar systems)
- Updates IP addresses, gateways, DNS servers, and routes
- Updates /etc/hosts entries
- Optional Pacemaker configuration updates
- Supports dry-run mode to preview changes
- Creates backups of modified files and configurations when requested
- Designed to work on RHEL 8, RHEL 9, and other Linux distributions
- Color-coded output for better readability

## Requirements

- Bash shell
- Root privileges (when not using dry-run mode)
- NetworkManager with nmcli command
- Pacemaker cluster software (optional, only needed if using the Pacemaker update feature)

## Usage

```bash
./change-site.sh [options] <from_subnet> <to_subnet>
```

### Arguments

- `<from_subnet>` - Source subnet (e.g., 192.168)
- `<to_subnet>` - Destination subnet (e.g., 172.23)

### Options

- `-h, --help` - Show help message
- `-p, --pacemaker` - Also update Pacemaker configuration
- `-n, --dry-run` - Show changes without applying them
- `-b, --backup` - Create backups of modified files

### Examples

Preview changes (dry-run mode):
```bash
./change-site.sh -n 192.168 172.23
```

Switch from 192.168.x.x to 172.23.x.x with backups:
```bash
sudo ./change-site.sh -b 192.168 172.23
```

Update all configurations including Pacemaker:
```bash
sudo ./change-site.sh -p -b 192.168 172.23
```

## Installation

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x change-site.sh
   ```

## How it Works

The script performs the following steps:

1. Validates the input subnet formats and checks for root privileges
2. Uses nmcli to find and update NetworkManager connections with IP addresses in the source subnet:
   - Modifies IPv4 addresses while preserving the last two octets
   - Updates gateways, DNS servers, and routes as needed
3. Updates /etc/hosts entries matching the source subnet
4. Optionally updates Pacemaker configuration if requested
5. Restarts NetworkManager to apply changes

## Security Considerations

- The script requires root privileges to modify system configuration files
- Always use the dry-run mode first to verify changes before applying them
- Consider creating backups with the `-b` option before making changes

## License

This project is open source and available under the [MIT License](LICENSE).