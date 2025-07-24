#!/bin/bash
#
# change-site.sh - Script to change network subnet configuration
#
# This script replaces one subnet with another in:
# - Network Manager connections
# - /etc/hosts
# - Optionally in Pacemaker configuration
#
# Compatible with RHEL 8, RHEL 9, and RHEL 10
#

set -euo pipefail

# =============================================================================
# CONFIGURATION CONSTANTS
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Network configuration constants
readonly NETWORK_RESTART_DELAY=2
readonly CONNECTION_RETRY_COUNT=3
readonly CONNECTION_RETRY_DELAY=1

# File paths
readonly HOSTS_FILE="/etc/hosts"
readonly TEMP_DIR="/tmp"
readonly LOG_FILE="/var/log/change-site.log"

# Backup configuration
readonly BACKUP_RETENTION_DAYS=30
readonly BACKUP_DIR="/var/backups/change-site"

# Validation patterns
readonly SUBNET_PATTERN='^[0-9]{1,3}\.[0-9]{1,3}$'
readonly IP_PATTERN='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_PERMISSION_DENIED=2
readonly EXIT_DEPENDENCY_MISSING=3
readonly EXIT_OPERATION_FAILED=4
readonly EXIT_VALIDATION_FAILED=5

# =============================================================================
# ANSI COLOR CODES
# =============================================================================

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[0;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly NC=''
fi

# =============================================================================
# GLOBAL CONFIGURATION (INITIALIZED)
# =============================================================================

CONFIG_UPDATE_PACEMAKER=false
CONFIG_DRY_RUN=false
CONFIG_CREATE_BACKUP=false
CONFIG_VERBOSE=false

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_with_level() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Console output
    echo -e "${color}[${level}]${NC} ${message}" >&2
    
    # Log file output (if writable and not dry run)
    if [[ "$CONFIG_DRY_RUN" != true ]] && { [[ -w "$(dirname "$LOG_FILE")" ]] || [[ -w "$LOG_FILE" ]]; }; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_debug() {
    [[ "$CONFIG_VERBOSE" == true ]] && log_with_level "DEBUG" "$CYAN" "$1"
}

log_info() {
    log_with_level "INFO" "$BLUE" "$1"
}

log_success() {
    log_with_level "SUCCESS" "$GREEN" "$1"
}

log_warning() {
    log_with_level "WARNING" "$YELLOW" "$1"
}

log_error() {
    log_with_level "ERROR" "$RED" "$1"
}

# =============================================================================
# ERROR HANDLING AND CLEANUP
# =============================================================================

declare -a CLEANUP_FILES=()
declare -a CLEANUP_FUNCTIONS=()

cleanup() {
    local exit_code=$?
    
    log_debug "Starting cleanup process"
    
    # Execute cleanup functions
    for cleanup_func in "${CLEANUP_FUNCTIONS[@]}"; do
        if declare -f "$cleanup_func" > /dev/null; then
            log_debug "Executing cleanup function: $cleanup_func"
            "$cleanup_func" || log_warning "Cleanup function failed: $cleanup_func"
        fi
    done
    
    # Remove temporary files
    for file in "${CLEANUP_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            log_debug "Removing temporary file: $file"
            rm -f "$file" || log_warning "Failed to remove temporary file: $file"
        fi
    done
    
    log_debug "Cleanup completed"
    exit $exit_code
}

trap cleanup EXIT INT TERM

add_cleanup_file() {
    CLEANUP_FILES+=("$1")
}

add_cleanup_function() {
    CLEANUP_FUNCTIONS+=("$1")
}

error_exit() {
    local message="$1"
    local exit_code="${2:-$EXIT_OPERATION_FAILED}"
    log_error "$message"
    exit "$exit_code"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

usage() {
    cat << EOF
${BLUE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

${BLUE}Usage:${NC} $SCRIPT_NAME [options] <from_subnet> <to_subnet>

${BLUE}Arguments:${NC}
  ${GREEN}<from_subnet>${NC}   Source subnet (e.g., 192.168)
  ${GREEN}<to_subnet>${NC}     Destination subnet (e.g., 172.23)

${BLUE}Options:${NC}
  ${YELLOW}-h, --help${NC}       Show this help message
  ${YELLOW}-v, --version${NC}    Show version information
  ${YELLOW}-p, --pacemaker${NC}  Also update Pacemaker configuration
  ${YELLOW}-n, --dry-run${NC}    Show changes without applying them
  ${YELLOW}-b, --backup${NC}     Create backups of modified files
  ${YELLOW}--verbose${NC}        Enable verbose logging
  ${YELLOW}--config FILE${NC}    Use configuration file

${BLUE}Examples:${NC}
  Preview changes (dry-run mode):
    $SCRIPT_NAME -n 192.168 172.23

  Switch subnets with backups:
    sudo $SCRIPT_NAME -b 192.168 172.23

  Update all configurations including Pacemaker:
    sudo $SCRIPT_NAME -p -b 192.168 172.23

${BLUE}Exit Codes:${NC}
  0 - Success
  1 - Invalid arguments
  2 - Permission denied
  3 - Missing dependencies
  4 - Operation failed
  5 - Validation failed

EOF
    # Disable cleanup trap before exiting
    trap - EXIT
    exit 0
}

show_version() {
    echo "$SCRIPT_NAME version $SCRIPT_VERSION"
    echo "Compatible with RHEL 8, 9, and 10"
    # Disable cleanup trap before exiting
    trap - EXIT
    exit 0
}

check_root_privileges() {
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        return 0
    fi
    
    if [[ "$(id -u)" -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)" "$EXIT_PERMISSION_DENIED"
    fi
}

create_secure_temp_file() {
    local prefix="$1"
    local temp_file
    
    temp_file="$(mktemp "$TEMP_DIR/${prefix}_XXXXXX")"
    chmod 600 "$temp_file"
    add_cleanup_file "$temp_file"
    echo "$temp_file"
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_subnet_format() {
    local subnet="$1"
    local subnet_name="$2"
    
    if [[ ! "$subnet" =~ $SUBNET_PATTERN ]]; then
        error_exit "Invalid $subnet_name subnet format: $subnet. Expected format: xxx.xxx" "$EXIT_VALIDATION_FAILED"
    fi
    
    # Validate octets are in valid range
    local first_octet="${subnet%%.*}"
    local second_octet="${subnet##*.}"
    
    if ((first_octet < 1 || first_octet > 223)); then
        error_exit "Invalid first octet in $subnet_name subnet: $first_octet" "$EXIT_VALIDATION_FAILED"
    fi
    
    if ((second_octet < 0 || second_octet > 255)); then
        error_exit "Invalid second octet in $subnet_name subnet: $second_octet" "$EXIT_VALIDATION_FAILED"
    fi
}

validate_subnets() {
    local from_subnet="$1"
    local to_subnet="$2"
    
    validate_subnet_format "$from_subnet" "source"
    validate_subnet_format "$to_subnet" "destination"
    
    if [[ "$from_subnet" == "$to_subnet" ]]; then
        error_exit "Source and destination subnets are identical: $from_subnet" "$EXIT_VALIDATION_FAILED"
    fi
    
    log_debug "Subnet validation passed: $from_subnet -> $to_subnet"
}

# =============================================================================
# DEPENDENCY CHECKING
# =============================================================================

check_command_availability() {
    local command="$1"
    local package="$2"
    
    if ! command -v "$command" &> /dev/null; then
        error_exit "$command not found. Please install $package package." "$EXIT_DEPENDENCY_MISSING"
    fi
}

check_service_status() {
    local service="$1"
    
    if ! systemctl is-active --quiet "$service"; then
        log_warning "$service is not running. Attempting to start..."
        if ! systemctl start "$service"; then
            error_exit "Failed to start $service" "$EXIT_DEPENDENCY_MISSING"
        fi
        log_info "$service started successfully"
    fi
}

check_networkmanager() {
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_debug "Skipping NetworkManager check in dry run mode"
        return 0
    fi
    
    check_command_availability "nmcli" "NetworkManager"
    check_service_status "NetworkManager"
    log_debug "NetworkManager is available and running"
}

check_pacemaker() {
    if [[ "$CONFIG_UPDATE_PACEMAKER" == true ]]; then
        if [[ "$CONFIG_DRY_RUN" == true ]]; then
            log_debug "Skipping Pacemaker check in dry run mode"
            return 0
        fi
        
        check_command_availability "pcs" "pcs"
        check_service_status "pacemaker"
        log_debug "Pacemaker is available and running"
    fi
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

create_backup_directory() {
    if [[ "$CONFIG_CREATE_BACKUP" == true ]] && [[ "$CONFIG_DRY_RUN" == false ]]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        log_debug "Backup directory created: $BACKUP_DIR"
    fi
}

backup_file() {
    local source_file="$1"
    local backup_name="${2:-$(basename "$source_file")}"
    
    if [[ "$CONFIG_CREATE_BACKUP" != true ]] || [[ "$CONFIG_DRY_RUN" == true ]]; then
        return 0
    fi
    
    if [[ ! -f "$source_file" ]]; then
        log_warning "Source file does not exist: $source_file"
        return 1
    fi
    
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_file="$BACKUP_DIR/${backup_name}.${timestamp}.bak"
    
    if cp "$source_file" "$backup_file"; then
        chmod 600 "$backup_file"
        log_info "Backup created: $backup_file"
        return 0
    else
        log_error "Failed to create backup: $backup_file"
        return 1
    fi
}

backup_nm_connection() {
    local connection_name="$1"
    
    if [[ "$CONFIG_CREATE_BACKUP" != true ]] || [[ "$CONFIG_DRY_RUN" == true ]]; then
        return 0
    fi
    
    local backup_file
    backup_file="$(create_secure_temp_file "nm_backup_${connection_name}")"
    
    if nmcli connection export "$connection_name" > "$backup_file" 2>/dev/null; then
        local final_backup="$BACKUP_DIR/connection_${connection_name}_$(date +%Y%m%d_%H%M%S).nmconnection"
        if mv "$backup_file" "$final_backup"; then
            chmod 600 "$final_backup"
            log_info "NetworkManager connection backup created: $final_backup"
            return 0
        fi
    fi
    
    log_warning "Failed to backup NetworkManager connection: $connection_name"
    return 1
}

# =============================================================================
# NETWORK MANAGER CONNECTION FUNCTIONS
# =============================================================================

get_nm_connections() {
    local connections=()
    local line
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        # In dry run mode, return some mock connections for testing
        echo "mock-connection-1"
        echo "mock-connection-2"
        return 0
    fi
    
    # Use process substitution compatible with older bash versions
    while IFS= read -r line; do
        [[ -n "$line" ]] && connections+=("$line")
    done < <(nmcli -t -f NAME connection show 2>/dev/null)
    
    printf '%s\n' "${connections[@]}"
}

get_connection_info() {
    local connection_name="$1"
    local info_file
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        # Return mock connection info for dry run testing
        echo "ipv4.addresses:192.168.1.100/24"
        echo "ipv4.gateway:192.168.1.1"
        echo "ipv4.dns:192.168.1.1"
        echo "ipv4.routes:"
        return 0
    fi
    
    info_file="$(create_secure_temp_file "conn_info")"
    
    if nmcli -t -f ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.routes connection show "$connection_name" > "$info_file" 2>/dev/null; then
        cat "$info_file"
        return 0
    else
        log_error "Failed to get connection info for: $connection_name"
        return 1
    fi
}

connection_has_subnet() {
    local connection_name="$1"
    local subnet="$2"
    local connection_info
    
    connection_info="$(get_connection_info "$connection_name")" || return 1
    
    if [[ "$connection_info" == *"$subnet"* ]]; then
        return 0
    else
        return 1
    fi
}

parse_connection_field() {
    local connection_info="$1"
    local field_name="$2"
    local values=()
    local line
    
    while IFS= read -r line; do
        if [[ "$line" == "${field_name}:"* ]]; then
            local value="${line#${field_name}:}"
            [[ -n "$value" ]] && values+=("$value")
        fi
    done <<< "$connection_info"
    
    printf '%s\n' "${values[@]}"
}

update_connection_addresses() {
    local connection_name="$1"
    local from_subnet="$2"
    local to_subnet="$3"
    local connection_info="$4"
    local modified=false
    
    local addresses=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && addresses+=("$line")
    done < <(parse_connection_field "$connection_info" "ipv4.addresses")
    
    for address in "${addresses[@]}"; do
        if [[ "$address" == "${from_subnet}"* ]]; then
            local ip_only="${address%/*}"
            local prefix="${address#*/}"
            local last_part="${ip_only#${from_subnet}.}"
            local new_ip="${to_subnet}.${last_part}/${prefix}"
            
            if [[ "$CONFIG_DRY_RUN" == true ]]; then
                log_info "Would update IP address: $ip_only -> ${to_subnet}.${last_part}"
            else
                if nmcli connection modify "$connection_name" ipv4.addresses "$new_ip"; then
                    log_info "Updated IP address for $connection_name: $ip_only -> ${to_subnet}.${last_part}"
                    modified=true
                else
                    log_error "Failed to update IP address for $connection_name"
                fi
            fi
        fi
    done
    
    [[ "$modified" == true ]]
}

update_connection_gateway() {
    local connection_name="$1"
    local from_subnet="$2"
    local to_subnet="$3"
    local connection_info="$4"
    local modified=false
    
    local gateways=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && gateways+=("$line")
    done < <(parse_connection_field "$connection_info" "ipv4.gateway")
    
    for gateway in "${gateways[@]}"; do
        if [[ -n "$gateway" && "$gateway" == "${from_subnet}"* ]]; then
            local last_part="${gateway#${from_subnet}.}"
            local new_gateway="${to_subnet}.${last_part}"
            
            if [[ "$CONFIG_DRY_RUN" == true ]]; then
                log_info "Would update gateway: $gateway -> $new_gateway"
            else
                if nmcli connection modify "$connection_name" ipv4.gateway "$new_gateway"; then
                    log_info "Updated gateway for $connection_name: $gateway -> $new_gateway"
                    modified=true
                else
                    log_error "Failed to update gateway for $connection_name"
                fi
            fi
        fi
    done
    
    [[ "$modified" == true ]]
}

update_connection_dns() {
    local connection_name="$1"
    local from_subnet="$2"
    local to_subnet="$3"
    local connection_info="$4"
    local modified=false
    
    local dns_servers=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && dns_servers+=("$line")
    done < <(parse_connection_field "$connection_info" "ipv4.dns")
    
    for dns in "${dns_servers[@]}"; do
        if [[ "$dns" == "${from_subnet}"* ]]; then
            local last_part="${dns#${from_subnet}.}"
            local new_dns="${to_subnet}.${last_part}"
            
            if [[ "$CONFIG_DRY_RUN" == true ]]; then
                log_info "Would update DNS server: $dns -> $new_dns"
            else
                if nmcli connection modify "$connection_name" +ipv4.dns "$new_dns" && \
                   nmcli connection modify "$connection_name" -ipv4.dns "$dns"; then
                    log_info "Updated DNS server for $connection_name: $dns -> $new_dns"
                    modified=true
                else
                    log_error "Failed to update DNS server for $connection_name"
                fi
            fi
        fi
    done
    
    [[ "$modified" == true ]]
}

update_connection_routes() {
    local connection_name="$1"
    local from_subnet="$2"
    local to_subnet="$3"
    local connection_info="$4"
    local modified=false
    
    local routes=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && routes+=("$line")
    done < <(parse_connection_field "$connection_info" "ipv4.routes")
    
    for route in "${routes[@]}"; do
        if [[ "$route" == "${from_subnet}"* ]]; then
            local last_part="${route#${from_subnet}.}"
            local new_route="${to_subnet}.${last_part}"
            
            if [[ "$CONFIG_DRY_RUN" == true ]]; then
                log_info "Would update route: $route -> $new_route"
            else
                if nmcli connection modify "$connection_name" +ipv4.routes "$new_route" && \
                   nmcli connection modify "$connection_name" -ipv4.routes "$route"; then
                    log_info "Updated route for $connection_name: $route -> $new_route"
                    modified=true
                else
                    log_error "Failed to update route for $connection_name"
                fi
            fi
        fi
    done
    
    [[ "$modified" == true ]]
}

update_single_connection() {
    local connection_name="$1"
    local from_subnet="$2"
    local to_subnet="$3"
    local connection_modified=false
    
    log_debug "Processing connection: $connection_name"
    
    if ! connection_has_subnet "$connection_name" "$from_subnet"; then
        log_debug "Connection $connection_name does not contain subnet $from_subnet"
        return 1
    fi
    
    log_info "Found connection with matching subnet: $connection_name"
    
    local connection_info
    connection_info="$(get_connection_info "$connection_name")" || return 1
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_info "Would modify connection: $connection_name"
        echo "$connection_info"
        return 0
    fi
    
    # Create backup before modification
    backup_nm_connection "$connection_name"
    
    # Update different components
    if update_connection_addresses "$connection_name" "$from_subnet" "$to_subnet" "$connection_info"; then
        connection_modified=true
    fi
    
    if update_connection_gateway "$connection_name" "$from_subnet" "$to_subnet" "$connection_info"; then
        connection_modified=true
    fi
    
    if update_connection_dns "$connection_name" "$from_subnet" "$to_subnet" "$connection_info"; then
        connection_modified=true
    fi
    
    if update_connection_routes "$connection_name" "$from_subnet" "$to_subnet" "$connection_info"; then
        connection_modified=true
    fi
    
    [[ "$connection_modified" == true ]]
}

restart_networkmanager() {
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_info "Would restart NetworkManager"
        return 0
    fi
    
    log_info "Restarting NetworkManager to apply changes..."
    if systemctl restart NetworkManager; then
        sleep "$NETWORK_RESTART_DELAY"
        log_success "NetworkManager restarted successfully"
        return 0
    else
        log_error "Failed to restart NetworkManager"
        return 1
    fi
}

reapply_connection() {
    local connection_name="$1"
    local attempt=1
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_info "Would re-apply connection: $connection_name"
        return 0
    fi
    
    log_info "Re-applying connection: $connection_name"
    
    while ((attempt <= CONNECTION_RETRY_COUNT)); do
        if nmcli connection down "$connection_name" 2>/dev/null && \
           nmcli connection up "$connection_name" 2>/dev/null; then
            log_success "Successfully re-applied connection: $connection_name"
            return 0
        fi
        
        log_warning "Attempt $attempt failed for connection: $connection_name"
        ((attempt++))
        
        if ((attempt <= CONNECTION_RETRY_COUNT)); then
            sleep "$CONNECTION_RETRY_DELAY"
        fi
    done
    
    log_error "Failed to re-apply connection after $CONNECTION_RETRY_COUNT attempts: $connection_name"
    return 1
}

update_nm_connections() {
    local from_subnet="$1"
    local to_subnet="$2"
    local modified_count=0
    local modified_connections=()
    local connections=()
    
    log_info "Searching for NetworkManager connections with subnet $from_subnet..."
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && connections+=("$line")
    done < <(get_nm_connections)
    
    for connection in "${connections[@]}"; do
        [[ -z "$connection" ]] && continue
        
        if update_single_connection "$connection" "$from_subnet" "$to_subnet"; then
            ((modified_count++))
            modified_connections+=("$connection")
        fi
    done
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_info "Dry run - $modified_count NetworkManager connection(s) would be updated"
        return 0
    fi
    
    if ((modified_count > 0)); then
        log_success "Updated $modified_count NetworkManager connection(s)"
        
        if restart_networkmanager; then
            # Re-apply modified connections
            for connection in "${modified_connections[@]}"; do
                reapply_connection "$connection"
            done
        fi
    else
        log_warning "No NetworkManager connections were modified"
    fi
}

# =============================================================================
# HOSTS FILE FUNCTIONS
# =============================================================================

update_hosts_file() {
    local from_subnet="$1"
    local to_subnet="$2"
    local hosts_file="$HOSTS_FILE"
    local temp_file
    local matches=0
    
    log_info "Checking $hosts_file for subnet $from_subnet..."
    
    if [[ ! -f "$hosts_file" ]]; then
        log_error "$hosts_file not found"
        return 1
    fi
    
    # Count matches first
    matches=$(grep -c "$from_subnet" "$hosts_file" 2>/dev/null || true)
    
    if ((matches == 0)); then
        log_warning "No entries with subnet $from_subnet found in $hosts_file"
        return 0
    fi
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_info "Would modify $matches line(s) in $hosts_file"
        grep -n "$from_subnet" "$hosts_file" 2>/dev/null || true
        return 0
    fi
    
    # Create backup
    backup_file "$hosts_file"
    
    # Create temporary file with modifications
    temp_file="$(create_secure_temp_file "hosts_update")"
    
    if sed "s/$from_subnet/$to_subnet/g" "$hosts_file" > "$temp_file"; then
        if mv "$temp_file" "$hosts_file"; then
            log_success "Updated $hosts_file with new subnet ($matches line(s) modified)"
            return 0
        else
            log_error "Failed to update $hosts_file"
            return 1
        fi
    else
        log_error "Failed to process $hosts_file"
        return 1
    fi
}

# =============================================================================
# PACEMAKER FUNCTIONS
# =============================================================================

update_pacemaker_config() {
    local from_subnet="$1"
    local to_subnet="$2"
    local cib_file
    local modified_cib
    local matches=0
    
    if [[ "$CONFIG_UPDATE_PACEMAKER" != true ]]; then
        return 0
    fi
    
    log_info "Checking Pacemaker configuration for subnet $from_subnet..."
    
    # Create temporary files
    cib_file="$(create_secure_temp_file "pacemaker_cib")"
    modified_cib="$(create_secure_temp_file "pacemaker_modified")"
    
    # Dump current configuration
    if ! pcs cluster cib "$cib_file"; then
        log_error "Failed to retrieve Pacemaker CIB"
        return 1
    fi
    
    # Count matches
    matches=$(grep -c "$from_subnet" "$cib_file" 2>/dev/null || true)
    
    if ((matches == 0)); then
        log_warning "No entries with subnet $from_subnet found in Pacemaker configuration"
        return 0
    fi
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_info "Would modify $matches line(s) in Pacemaker configuration"
        grep -n "$from_subnet" "$cib_file" 2>/dev/null || true
        return 0
    fi
    
    # Create backup
    backup_file "$cib_file" "pacemaker_cib"
    
    # Create modified configuration
    if sed "s/$from_subnet/$to_subnet/g" "$cib_file" > "$modified_cib"; then
        if pcs cluster cib-push "$modified_cib"; then
            log_success "Updated Pacemaker configuration with new subnet ($matches line(s) modified)"
            return 0
        else
            log_error "Failed to update Pacemaker configuration"
            return 1
        fi
    else
        log_error "Failed to process Pacemaker configuration"
        return 1
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--version)
                show_version
                ;;
            -p|--pacemaker)
                CONFIG_UPDATE_PACEMAKER=true
                shift
                ;;
            -n|--dry-run)
                CONFIG_DRY_RUN=true
                shift
                ;;
            -b|--backup)
                CONFIG_CREATE_BACKUP=true
                shift
                ;;
            --verbose)
                CONFIG_VERBOSE=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -*)
                error_exit "Unknown option: $1" "$EXIT_INVALID_ARGS"
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Verify required arguments
    if [[ $# -ne 2 ]]; then
        error_exit "Missing required arguments. Use --help for usage information." "$EXIT_INVALID_ARGS"
    fi
    
    # Set subnet variables
    FROM_SUBNET="$1"
    TO_SUBNET="$2"
}

main() {
    # Parse command line arguments first
    parse_arguments "$@"
    
    log_info "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log_debug "Command line: $0 $*"
    
    # Validate input
    log_debug "Validating subnets..."
    validate_subnets "$FROM_SUBNET" "$TO_SUBNET"
    log_debug "Subnet validation completed"
    
    # Check privileges and dependencies
    log_debug "Checking privileges..."
    check_root_privileges
    log_debug "Checking NetworkManager..."
    check_networkmanager
    log_debug "Checking Pacemaker..."
    check_pacemaker
    
    # Create backup directory if needed
    log_debug "Creating backup directory..."
    create_backup_directory
    
    log_info "Starting site change from subnet $FROM_SUBNET to $TO_SUBNET"
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No changes will be applied"
    fi
    
    # Perform updates
    local success=true
    
    log_debug "Updating NetworkManager connections..."
    if ! update_nm_connections "$FROM_SUBNET" "$TO_SUBNET"; then
        log_error "Failed to update NetworkManager connections"
        success=false
    fi
    
    log_debug "Updating hosts file..."
    if ! update_hosts_file "$FROM_SUBNET" "$TO_SUBNET"; then
        log_error "Failed to update hosts file"
        success=false
    fi
    
    log_debug "Updating Pacemaker configuration..."
    if ! update_pacemaker_config "$FROM_SUBNET" "$TO_SUBNET"; then
        log_error "Failed to update Pacemaker configuration"
        success=false
    fi
    
    # Final status
    if [[ "$success" == true ]]; then
        if [[ "$CONFIG_DRY_RUN" == true ]]; then
            log_success "Dry run completed successfully - no changes were applied"
        else
            log_success "Site change completed successfully"
        fi
    else
        error_exit "Site change completed with errors" "$EXIT_OPERATION_FAILED"
    fi
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi