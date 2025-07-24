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
readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Network configuration constants
NETWORK_RESTART_DELAY=2
CONNECTION_RETRY_COUNT=3
readonly CONNECTION_RETRY_DELAY=1

# File paths
readonly HOSTS_FILE="/etc/hosts"
readonly TEMP_DIR="/tmp"
LOG_FILE="/var/log/change-site.log"

# Backup configuration
BACKUP_RETENTION_DAYS=30
BACKUP_DIR="/var/backups/change-site"

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
CONFIG_PROFILE=""
CONFIG_FILE=""
CONFIG_MAX_PARALLEL_CONNECTIONS=5

# Configuration file paths (in order of precedence)
readonly DEFAULT_CONFIG_PATHS=(
    "$SCRIPT_DIR/change-site.conf"
    "/etc/change-site/change-site.conf"
    "$HOME/.config/change-site/change-site.conf"
    "$HOME/.change-site.conf"
)

# Subnet pair mappings (loaded from config)
declare -A SUBNET_PAIRS

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
       $SCRIPT_NAME [options] --pair <pair_name>
       $SCRIPT_NAME --list-pairs
       $SCRIPT_NAME --rollback <operation_id>

${BLUE}Arguments:${NC}
  ${GREEN}<from_subnet>${NC}   Source subnet (e.g., 192.168)
  ${GREEN}<to_subnet>${NC}     Destination subnet (e.g., 172.23)
  ${GREEN}<pair_name>${NC}     Predefined subnet pair name
  ${GREEN}<operation_id>${NC}  Operation ID for rollback

${BLUE}Options:${NC}
  ${YELLOW}-h, --help${NC}       Show this help message
  ${YELLOW}-v, --version${NC}    Show version information
  ${YELLOW}-p, --pacemaker${NC}  Also update Pacemaker configuration
  ${YELLOW}-n, --dry-run${NC}    Show changes without applying them
  ${YELLOW}-b, --backup${NC}     Create backups of modified files
  ${YELLOW}--verbose${NC}        Enable verbose logging
  ${YELLOW}--config FILE${NC}    Use specific configuration file
  ${YELLOW}--profile NAME${NC}   Use configuration profile
  ${YELLOW}--pair NAME${NC}      Use predefined subnet pair
  ${YELLOW}--list-pairs${NC}     List available subnet pairs
  ${YELLOW}--rollback ID${NC}    Rollback a previous operation

${BLUE}Configuration:${NC}
  Configuration files are searched in this order:
  1. File specified with --config
  2. ./change-site.conf
  3. /etc/change-site/change-site.conf
  4. ~/.config/change-site/change-site.conf
  5. ~/.change-site.conf

${BLUE}Examples:${NC}
  Preview changes (dry-run mode):
    $SCRIPT_NAME -n 192.168 172.23

  Switch subnets with backups:
    sudo $SCRIPT_NAME -b 192.168 172.23

  Use predefined subnet pair:
    sudo $SCRIPT_NAME --pair OFFICE_TO_DATACENTER

  List available subnet pairs:
    $SCRIPT_NAME --list-pairs

  Rollback a previous operation:
    sudo $SCRIPT_NAME --rollback 20250724_095500_12345

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

# =============================================================================
# CONFIGURATION FILE FUNCTIONS
# =============================================================================

find_config_file() {
    # If config file specified via command line, use it
    if [[ -n "$CONFIG_FILE" ]]; then
        if [[ -f "$CONFIG_FILE" ]]; then
            echo "$CONFIG_FILE"
            return 0
        else
            error_exit "Specified config file not found: $CONFIG_FILE" "$EXIT_VALIDATION_FAILED"
        fi
    fi
    
    # Search default locations
    local config_path
    for config_path in "${DEFAULT_CONFIG_PATHS[@]}"; do
        if [[ -f "$config_path" ]]; then
            echo "$config_path"
            return 0
        fi
    done
    
    # No config file found - this is not an error
    return 1
}

parse_config_line() {
    local line="$1"
    local current_section="$2"
    
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && return 0
    [[ "$line" =~ ^[[:space:]]*$ ]] && return 0
    
    # Check for section headers
    if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
        echo "SECTION:${BASH_REMATCH[1]}"
        return 0
    fi
    
    # Parse key=value pairs
    if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]// /}"  # Remove spaces
        local value="${BASH_REMATCH[2]}"
        
        # Apply profile filtering - only filter if we're in a specific section AND have a profile set
        if [[ -n "$current_section" && -n "${CONFIG_PROFILE:-}" && "$current_section" != "$CONFIG_PROFILE" ]]; then
            return 0
        fi
        
        # If we have a profile set but we're not in any section, only process if no profile is active
        if [[ -z "$current_section" && -n "${CONFIG_PROFILE:-}" ]]; then
            # We're in global section with a profile set - process global settings
            echo "CONFIG:$key:$value"
            return 0
        fi
        
        # If no profile is set, process everything except profile-specific sections
        if [[ -z "${CONFIG_PROFILE:-}" && -n "$current_section" ]]; then
            return 0
        fi
        
        echo "CONFIG:$key:$value"
        return 0
    fi
    
    return 0
}

apply_config_setting() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        CREATE_BACKUP)
            CONFIG_CREATE_BACKUP="$value"
            ;;
        UPDATE_PACEMAKER)
            CONFIG_UPDATE_PACEMAKER="$value"
            ;;
        VERBOSE)
            CONFIG_VERBOSE="$value"
            ;;
        DRY_RUN)
            CONFIG_DRY_RUN="$value"
            ;;
        LOG_LEVEL)
            CONFIG_LOG_LEVEL="$value"
            ;;
        BACKUP_RETENTION_DAYS)
            BACKUP_RETENTION_DAYS="$value"
            ;;
        BACKUP_DIR)
            BACKUP_DIR="$value"
            ;;
        LOG_FILE)
            LOG_FILE="$value"
            ;;
        NETWORK_RESTART_DELAY)
            NETWORK_RESTART_DELAY="$value"
            ;;
        CONNECTION_RETRY_COUNT)
            CONNECTION_RETRY_COUNT="$value"
            ;;
        CONNECTION_RETRY_DELAY)
            # CONNECTION_RETRY_DELAY is readonly, skipping configuration
            echo "[WARNING] CONNECTION_RETRY_DELAY is readonly and cannot be configured" >&2
            ;;
        MAX_PARALLEL_CONNECTIONS)
            CONFIG_MAX_PARALLEL_CONNECTIONS="$value"
            ;;
        SUBNET_PAIR_*)
            local pair_name="${key#SUBNET_PAIR_}"
            SUBNET_PAIRS["$pair_name"]="$value"
            ;;
        *)
            log_warning "Unknown configuration key: $key"
            ;;
    esac
}

load_configuration() {
    # Temporarily disable strict error handling for configuration loading
    set +e
    
    local config_file
    config_file="$(find_config_file)" || {
        log_debug "No configuration file found, using defaults"
        set -e
        return 0
    }
    
    log_debug "Loading configuration from: $config_file"
    
    local line
    local current_section=""
    local line_count=0
    
    # Read file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_count++))
        log_debug "Processing line $line_count: $line"
        
        local parsed
        parsed="$(parse_config_line "$line" "$current_section")"
        
        if [[ "$parsed" == SECTION:* ]]; then
            current_section="${parsed#SECTION:}"
            log_debug "Entering configuration section: $current_section"
        elif [[ "$parsed" == CONFIG:* ]]; then
            local key="${parsed#CONFIG:}"
            key="${key%%:*}"
            local value="${parsed#CONFIG:*:}"
            apply_config_setting "$key" "$value"
            log_debug "Applied config: $key=$value"
        fi
    done < "$config_file"
    
    log_debug "Configuration loaded successfully, processed $line_count lines"
    
    # Restore strict error handling
    set -e
}

list_subnet_pairs() {
    local count=0
    if [[ -v SUBNET_PAIRS ]]; then
        count=${#SUBNET_PAIRS[@]}
    fi
    
    if [[ $count -eq 0 ]]; then
        echo "No subnet pairs defined in configuration"
        return 0
    fi
    
    echo "Available subnet pairs:"
    local pair_name
    for pair_name in "${!SUBNET_PAIRS[@]}"; do
        local pair_value="${SUBNET_PAIRS[$pair_name]}"
        local from_subnet="${pair_value%:*}"
        local to_subnet="${pair_value#*:}"
        echo "  $pair_name: $from_subnet -> $to_subnet"
    done
}

resolve_subnet_pair() {
    local pair_name="$1"
    
    if [[ -n "${SUBNET_PAIRS[$pair_name]:-}" ]]; then
        local pair_value="${SUBNET_PAIRS[$pair_name]}"
        local from_subnet="${pair_value%:*}"
        local to_subnet="${pair_value#*:}"
        echo "$from_subnet $to_subnet"
        return 0
    else
        error_exit "Subnet pair not found: $pair_name" "$EXIT_VALIDATION_FAILED"
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
        echo "$backup_file" >> "$BACKUP_DIR/.backup_manifest"
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
            echo "nm:$connection_name:$final_backup" >> "$BACKUP_DIR/.backup_manifest"
            echo "$final_backup"  # Return the backup file path
            return 0
        fi
    fi
    
    log_warning "Failed to backup NetworkManager connection: $connection_name"
    return 1
}

# =============================================================================
# ROLLBACK FUNCTIONS
# =============================================================================

create_rollback_point() {
    local operation_id="$1"
    local rollback_file="$BACKUP_DIR/.rollback_${operation_id}"
    
    if [[ "$CONFIG_CREATE_BACKUP" != true ]] || [[ "$CONFIG_DRY_RUN" == true ]]; then
        return 0
    fi
    
    # Create rollback metadata
    {
        echo "# Rollback point created: $(date)"
        echo "OPERATION_ID=$operation_id"
        echo "FROM_SUBNET=$FROM_SUBNET"
        echo "TO_SUBNET=$TO_SUBNET"
        echo "TIMESTAMP=$(date +%Y%m%d_%H%M%S)"
        echo "# Backup files created during this operation:"
    } > "$rollback_file"
    
    chmod 600 "$rollback_file"
    log_debug "Rollback point created: $rollback_file"
}

add_to_rollback_manifest() {
    local operation_id="$1"
    local backup_type="$2"
    local backup_file="$3"
    local original_file="$4"
    local rollback_file="$BACKUP_DIR/.rollback_${operation_id}"
    
    if [[ "$CONFIG_CREATE_BACKUP" == true ]] && [[ "$CONFIG_DRY_RUN" == false ]]; then
        echo "$backup_type:$original_file:$backup_file" >> "$rollback_file"
    fi
}

list_rollback_points() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backup directory found"
        return 1
    fi
    
    local rollback_files=()
    while IFS= read -r -d '' file; do
        rollback_files+=("$file")
    done < <(find "$BACKUP_DIR" -name ".rollback_*" -print0 2>/dev/null)
    
    local count=0
    if [[ -v rollback_files ]]; then
        count=${#rollback_files[@]}
    fi
    
    if [[ $count -eq 0 ]]; then
        echo "No rollback points found"
        return 1
    fi
    
    echo "Available rollback points:"
    local file
    for file in "${rollback_files[@]}"; do
        local operation_id="${file##*/.rollback_}"
        local timestamp
        local from_subnet
        local to_subnet
        
        # Extract metadata
        while IFS= read -r line; do
            case "$line" in
                TIMESTAMP=*)
                    timestamp="${line#TIMESTAMP=}"
                    ;;
                FROM_SUBNET=*)
                    from_subnet="${line#FROM_SUBNET=}"
                    ;;
                TO_SUBNET=*)
                    to_subnet="${line#TO_SUBNET=}"
                    ;;
            esac
        done < "$file"
        
        echo "  $operation_id ($timestamp): $from_subnet -> $to_subnet"
    done
}

perform_rollback() {
    local operation_id="$1"
    local rollback_file="$BACKUP_DIR/.rollback_${operation_id}"
    
    if [[ ! -f "$rollback_file" ]]; then
        error_exit "Rollback point not found: $operation_id" "$EXIT_VALIDATION_FAILED"
    fi
    
    log_info "Starting rollback for operation: $operation_id"
    
    # Read rollback manifest
    local line
    local rollback_count=0
    while IFS= read -r line; do
        # Skip comments and metadata
        [[ "$line" =~ ^# ]] && continue
        [[ "$line" =~ ^[A-Z_]+=.* ]] && continue
        [[ -z "$line" ]] && continue
        
        # Parse backup entry: type:original_file:backup_file
        local backup_type="${line%%:*}"
        local remaining="${line#*:}"
        local original_file="${remaining%%:*}"
        local backup_file="${remaining#*:}"
        
        case "$backup_type" in
            file)
                if [[ -f "$backup_file" ]]; then
                    if cp "$backup_file" "$original_file"; then
                        log_info "Restored file: $original_file"
                        ((rollback_count++))
                    else
                        log_error "Failed to restore file: $original_file"
                    fi
                else
                    log_warning "Backup file not found: $backup_file"
                fi
                ;;
            nm)
                local connection_name="${original_file}"
                if [[ -f "$backup_file" ]]; then
                    if nmcli connection import "$backup_file" 2>/dev/null; then
                        log_info "Restored NetworkManager connection: $connection_name"
                        ((rollback_count++))
                    else
                        log_error "Failed to restore NetworkManager connection: $connection_name"
                    fi
                else
                    log_warning "NetworkManager backup not found: $backup_file"
                fi
                ;;
            *)
                log_warning "Unknown backup type: $backup_type"
                ;;
        esac
    done < "$rollback_file"
    
    if ((rollback_count > 0)); then
        log_success "Rollback completed: $rollback_count items restored"
        
        # Restart NetworkManager if any connections were restored
        if grep -q "^nm:" "$rollback_file" 2>/dev/null; then
            restart_networkmanager
        fi
    else
        log_warning "No items were restored during rollback"
    fi
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
            local value="${line#"${field_name}":}"
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
            local last_part="${ip_only#"${from_subnet}".}"
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
            local last_part="${gateway#"${from_subnet}".}"
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
            local last_part="${dns#"${from_subnet}".}"
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
            local last_part="${route#"${from_subnet}".}"
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
    local operation_id="${4:-}"
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
    local backup_file
    backup_file="$(backup_nm_connection "$connection_name")"
    if [[ -n "$operation_id" && -n "$backup_file" ]]; then
        add_to_rollback_manifest "$operation_id" "nm" "$backup_file" "$connection_name"
    fi
    
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
    local operation_id="${3:-}"
    local modified_count=0
    local modified_connections=()
    local connections=()
    
    log_info "Searching for NetworkManager connections with subnet $from_subnet..."
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && connections+=("$line")
    done < <(get_nm_connections)
    
    for connection in "${connections[@]}"; do
        [[ -z "$connection" ]] && continue
        
        if update_single_connection "$connection" "$from_subnet" "$to_subnet" "$operation_id"; then
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
            --profile)
                CONFIG_PROFILE="$2"
                shift 2
                ;;
            --list-pairs)
                # Set flag to list pairs after configuration is loaded
                LIST_PAIRS_FLAG=true
                shift
                ;;
            --pair)
                # Store pair name to resolve after configuration is loaded
                PAIR_NAME="$2"
                shift 2
                ;;
            --rollback)
                # Store rollback ID to process after configuration is loaded
                ROLLBACK_ID="$2"
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
    
    # Handle special operations that need configuration
    if [[ "${LIST_PAIRS_FLAG:-false}" == true ]]; then
        load_configuration
        list_subnet_pairs
        # Disable cleanup trap before exiting
        trap - EXIT
        exit 0
    fi
    
    if [[ -n "${ROLLBACK_ID:-}" ]]; then
        load_configuration
        perform_rollback "$ROLLBACK_ID"
        # Disable cleanup trap before exiting
        trap - EXIT
        exit 0
    fi
    
    if [[ -n "${PAIR_NAME:-}" ]]; then
        load_configuration
        local subnets
        subnets="$(resolve_subnet_pair "$PAIR_NAME")"
        read -r FROM_SUBNET TO_SUBNET <<< "$subnets"
    fi
    
    # If using --pair, we already have the subnets
    if [[ -n "${FROM_SUBNET:-}" && -n "${TO_SUBNET:-}" ]]; then
        return 0
    fi
    
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
    
    # Load configuration after argument parsing
    load_configuration
    
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
    
    # Create rollback point
    local operation_id="$(date +%Y%m%d_%H%M%S)_$$"
    create_rollback_point "$operation_id"
    
    log_info "Starting site change from subnet $FROM_SUBNET to $TO_SUBNET"
    log_debug "Operation ID: $operation_id"
    
    if [[ "$CONFIG_DRY_RUN" == true ]]; then
        log_info "DRY RUN MODE - No changes will be applied"
    fi
    
    # Perform updates
    local success=true
    
    log_debug "Updating NetworkManager connections..."
    if ! update_nm_connections "$FROM_SUBNET" "$TO_SUBNET" "$operation_id"; then
        log_error "Failed to update NetworkManager connections"
        success=false
    fi
    
    log_debug "Updating hosts file..."
    if ! update_hosts_file "$FROM_SUBNET" "$TO_SUBNET" "$operation_id"; then
        log_error "Failed to update hosts file"
        success=false
    fi
    
    log_debug "Updating Pacemaker configuration..."
    if ! update_pacemaker_config "$FROM_SUBNET" "$TO_SUBNET" "$operation_id"; then
        log_error "Failed to update Pacemaker configuration"
        success=false
    fi
    
    # Final status
    if [[ "$success" == true ]]; then
        if [[ "$CONFIG_DRY_RUN" == true ]]; then
            log_success "Dry run completed successfully - no changes were applied"
        else
            log_success "Site change completed successfully"
            log_info "Rollback available with: $SCRIPT_NAME --rollback $operation_id"
        fi
    else
        if [[ "$CONFIG_CREATE_BACKUP" == true ]] && [[ "$CONFIG_DRY_RUN" == false ]]; then
            log_error "Operation failed - consider rollback with: $SCRIPT_NAME --rollback $operation_id"
        fi
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