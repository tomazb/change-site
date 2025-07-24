#!/bin/bash
#
# change-site.sh - Script to change network subnet configuration
#
# This script replaces one subnet with another in:
# - Network Manager connections
# - /etc/hosts
# - Optionally in Pacemaker configuration
#
# Compatible with RHEL 8 and RHEL 9
#

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo -e "${BLUE}Usage:${NC} $0 [options] <from_subnet> <to_subnet>"
    echo -e ""
    echo -e "Arguments:"
    echo -e "  ${GREEN}<from_subnet>${NC}   Source subnet (e.g., 192.168)"
    echo -e "  ${GREEN}<to_subnet>${NC}     Destination subnet (e.g., 172.23)"
    echo -e ""
    echo -e "Options:"
    echo -e "  ${YELLOW}-h, --help${NC}       Show this help message"
    echo -e "  ${YELLOW}-p, --pacemaker${NC}  Also update Pacemaker configuration"
    echo -e "  ${YELLOW}-n, --dry-run${NC}    Show changes without applying them"
    echo -e "  ${YELLOW}-b, --backup${NC}     Create backups of modified files"
    echo -e ""
    echo -e "Example: $0 192.168 172.23"
    exit 1
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        local backup="${file}.$(date +%Y%m%d%H%M%S).bak"
        cp "$file" "$backup"
        log_info "Backup created: $backup"
    fi
}

# Check NetworkManager is installed and running
check_nm() {
    if ! command -v nmcli &> /dev/null; then
        log_error "NetworkManager (nmcli) not found. Please install NetworkManager."
        exit 1
    fi

    if ! systemctl is-active --quiet NetworkManager; then
        log_warning "NetworkManager is not running. Attempting to start..."
        systemctl start NetworkManager
    fi
}

# Update Network Manager connections
update_nm_connections() {
    local from_subnet=$1
    local to_subnet=$2
    local dry_run=$3
    
    log_info "Searching for Network Manager connections with IP addresses in subnet $from_subnet..."
    
    # Get all connections
    local connections
    mapfile -t connections < <(nmcli -t -f NAME connection show)
    local modified=0
    local modified_connections=()
    
    for conn_name in "${connections[@]}"; do
        # Get only the relevant fields we need using optimized command
        local ip_info
        mapfile -t ip_info < <(nmcli -t -f ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.routes connection show "$conn_name")
        
        # Check if connection has IP addresses with the from_subnet
        local subnet_found=false
        for line in "${ip_info[@]}"; do
            if [[ "$line" == *"$from_subnet"* ]]; then
                subnet_found=true
                break
            fi
        done
        
        if [[ "$subnet_found" == true ]]; then
            log_info "Found connection with matching subnet: $conn_name"
            
            # Extract specific fields using bash parameter expansion
            local ip_addresses=()
            local gateway=""
            local dns_servers=()
            local routes=()
            
            for line in "${ip_info[@]}"; do
                if [[ "$line" == ipv4.addresses:* ]]; then
                    ip_addresses+=("${line#ipv4.addresses:}")
                elif [[ "$line" == ipv4.gateway:* ]]; then
                    gateway="${line#ipv4.gateway:}"
                elif [[ "$line" == ipv4.dns:* ]]; then
                    dns_servers+=("${line#ipv4.dns:}")
                elif [[ "$line" == ipv4.routes:* ]]; then
                    routes+=("${line#ipv4.routes:}")
                fi
            done
            
            if [ "$dry_run" = true ]; then
                log_info "Would modify connection: $conn_name"
                printf '%s\n' "${ip_info[@]}"
                echo "Would replace $from_subnet with $to_subnet in IP configuration"
            else
                # Create backup of connection if requested
                if [ "$BACKUP" = true ]; then
                    local backup_file
                    backup_file=$(mktemp "/tmp/connection_${conn_name}_XXXXXX.nmconnection")
                    if nmcli connection export "$conn_name" > "$backup_file"; then
                        log_info "Backup created: $backup_file"
                    else
                        log_warning "Failed to create backup for connection: $conn_name"
                        rm -f "$backup_file"
                    fi
                fi
                
                # Modify IP configuration
                local modified_conn=false
                
                # Process each IP address
                for ip_addr in "${ip_addresses[@]}"; do
                    # Extract parts of the IP address using parameter expansion
                    local ip_only="${ip_addr%/*}"
                    local prefix="${ip_addr#*/}"
                    
                    # Replace subnet if it matches using bash pattern matching
                    if [[ "$ip_only" == $from_subnet* ]]; then
                        local last_octet="${ip_only#$from_subnet.}"
                        local new_ip="$to_subnet.$last_octet/$prefix"
                        
                        if nmcli connection modify "$conn_name" ipv4.addresses "$new_ip"; then
                            log_info "Updated IP address for $conn_name: $ip_only → $to_subnet.$last_octet"
                            modified_conn=true
                        fi
                    fi
                done
                
                # Update gateway if needed
                if [[ -n "$gateway" && "$gateway" == $from_subnet* ]]; then
                    local gw_last_octet="${gateway#$from_subnet.}"
                    local new_gw="$to_subnet.$gw_last_octet"
                    
                    if nmcli connection modify "$conn_name" ipv4.gateway "$new_gw"; then
                        log_info "Updated gateway for $conn_name: $gateway → $new_gw"
                        modified_conn=true
                    fi
                fi
                
                # Update DNS servers if needed
                for dns in "${dns_servers[@]}"; do
                    if [[ "$dns" == $from_subnet* ]]; then
                        local dns_last_octet="${dns#$from_subnet.}"
                        local new_dns="$to_subnet.$dns_last_octet"
                        
                        # Use + to append DNS servers rather than replacing
                        if nmcli connection modify "$conn_name" +ipv4.dns "$new_dns"; then
                            log_info "Added new DNS server for $conn_name: $new_dns"
                            
                            # Remove old DNS server
                            if nmcli connection modify "$conn_name" -ipv4.dns "$dns"; then
                                log_info "Removed old DNS server for $conn_name: $dns"
                                modified_conn=true
                            fi
                        fi
                    fi
                done
                
                # Update route destinations if needed
                for route in "${routes[@]}"; do
                    if [[ "$route" == $from_subnet* ]]; then
                        local route_last_octet="${route#$from_subnet.}"
                        local new_route="$to_subnet.$route_last_octet"
                        
                        # Add new route
                        if nmcli connection modify "$conn_name" +ipv4.routes "$new_route"; then
                            log_info "Added new route for $conn_name: $new_route"
                            
                            # Remove old route
                            if nmcli connection modify "$conn_name" -ipv4.routes "$route"; then
                                log_info "Removed old route for $conn_name: $route"
                                modified_conn=true
                            fi
                        fi
                    fi
                done
                
                if [ "$modified_conn" = true ]; then
                    modified=$((modified + 1))
                    modified_connections+=("$conn_name")
                fi
            fi
        fi
    done
    
    if [ "$dry_run" = true ]; then
        log_info "Dry run - NetworkManager connections would be updated"
    else
        if [ $modified -gt 0 ]; then
            log_success "Updated $modified NetworkManager connection(s)"
            log_info "Restarting NetworkManager to apply changes..."
            systemctl restart NetworkManager
            
            # Re-apply the connections to ensure changes take effect
            log_info "Re-applying modified connections..."
            sleep 2 # Give NetworkManager some time to restart
            for conn in "${modified_connections[@]}"; do
                log_info "Re-applying connection: $conn"
                if nmcli connection down "$conn" && nmcli connection up "$conn"; then
                    log_success "Successfully re-applied connection: $conn"
                else
                    log_warning "Failed to re-apply connection: $conn"
                fi
            done
        else
            log_warning "No NetworkManager connections were modified"
        fi
    fi
}

# Update /etc/hosts file
update_hosts_file() {
    local from_subnet=$1
    local to_subnet=$2
    local dry_run=$3
    local hosts_file="/etc/hosts"
    
    log_info "Checking /etc/hosts file for subnet $from_subnet..."
    
    if [ ! -f "$hosts_file" ]; then
        log_error "/etc/hosts file not found"
        return
    fi
    
    # Read hosts file content into an array
    local hosts_content
    mapfile -t hosts_content < "$hosts_file"
    
    # Check for subnet match and count matches
    local matches=0
    local match_lines=()
    local i=0
    
    for line in "${hosts_content[@]}"; do
        if [[ "$line" == *"$from_subnet"* ]]; then
            ((matches++))
            match_lines+=("$((i+1)):$line")
        fi
        ((i++))
    done
    
    if ((matches > 0)); then
        if [ "$BACKUP" = true ]; then
            backup_file "$hosts_file"
        fi
        
        if [ "$dry_run" = true ]; then
            log_info "Would modify file: $hosts_file"
            printf '%s\n' "${match_lines[@]}"
        else
            # Using sed is still the most efficient for this specific task
            sed -i "s/$from_subnet/$to_subnet/g" "$hosts_file"
            log_success "Updated /etc/hosts with new subnet"
        fi
    else
        log_warning "No entries with subnet $from_subnet found in /etc/hosts"
    fi
}

# Update Pacemaker configuration if requested
update_pacemaker() {
    local from_subnet=$1
    local to_subnet=$2
    local dry_run=$3
    
    log_info "Checking for Pacemaker configuration..."
    
    if ! command -v pcs &> /dev/null; then
        log_warning "Pacemaker tools (pcs) not found. Skipping Pacemaker configuration update."
        return
    fi
    
    if ! systemctl is-active --quiet pacemaker; then
        log_warning "Pacemaker service is not running. Skipping Pacemaker configuration update."
        return
    fi
    
    # Dump current configuration using mktemp for secure file creation
    local cib_file
    cib_file=$(mktemp "/tmp/pacemaker_cib_XXXXXX.xml")
    if ! pcs cluster cib "$cib_file"; then
        log_error "Failed to retrieve Pacemaker CIB"
        rm -f "$cib_file"
        return
    fi
    
    if [ ! -f "$cib_file" ]; then
        log_error "Failed to create Pacemaker CIB file"
        return
    fi
    
    # Read CIB content into an array
    local cib_content
    mapfile -t cib_content < "$cib_file"
    
    # Check for subnet match and count matches
    local matches=0
    local match_lines=()
    local i=0
    
    for line in "${cib_content[@]}"; do
        if [[ "$line" == *"$from_subnet"* ]]; then
            ((matches++))
            match_lines+=("$((i+1)):$line")
        fi
        ((i++))
    done
    
    if ((matches > 0)); then
        if [ "$BACKUP" = true ]; then
            backup_file "$cib_file"
        fi
        
        if [ "$dry_run" = true ]; then
            log_info "Would modify Pacemaker configuration:"
            printf '%s\n' "${match_lines[@]}"
        else
            local modified_cib
            modified_cib=$(mktemp "/tmp/pacemaker_modified_XXXXXX.xml")
            
            {
                for line in "${cib_content[@]}"; do
                    if [[ "$line" == *"$from_subnet"* ]]; then
                        # Replace subnet in the line using bash parameter expansion
                        line="${line//$from_subnet/$to_subnet}"
                    fi
                    echo "$line"
                done
            } > "$modified_cib"
            
            if pcs cluster cib-push "$modified_cib"; then
                log_success "Updated Pacemaker configuration with new subnet"
            else
                log_error "Failed to update Pacemaker configuration"
            fi
            
            rm -f "$modified_cib"
        fi
    else
        log_warning "No entries with subnet $from_subnet found in Pacemaker configuration"
    fi
    
    # Always clean up temporary files
    rm -f "$cib_file"
}

# Main function
main() {
    # Parse command line arguments
    local UPDATE_PACEMAKER=false
    local DRY_RUN=false
    # Make BACKUP global so other functions can access it
    BACKUP=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -p|--pacemaker)
                UPDATE_PACEMAKER=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -b|--backup)
                BACKUP=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Verify arguments
    if [ $# -ne 2 ]; then
        log_error "Missing required arguments"
        usage
    fi
    
    FROM_SUBNET=$1
    TO_SUBNET=$2
    
    # Validate subnet format with enhanced check
    if ! [[ "$FROM_SUBNET" =~ ^[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "Invalid source subnet format. Expected format: xxx.xxx"
        exit 1
    fi
    
    if ! [[ "$TO_SUBNET" =~ ^[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "Invalid destination subnet format. Expected format: xxx.xxx"
        exit 1
    fi
    
    # Additional validation for first octet (only standard classes)
    local first_octet_from=${FROM_SUBNET%%.*}
    local first_octet_to=${TO_SUBNET%%.*}
    if ((first_octet_from > 223 || first_octet_from == 0)) || ((first_octet_to > 223 || first_octet_to == 0)); then
        log_warning "Warning: One of the subnets contains a potentially invalid first octet"
    fi
    
    if [ "$FROM_SUBNET" = "$TO_SUBNET" ]; then
        log_error "Source and destination subnets are identical"
        exit 1
    fi
    
    # Escape dots in subnet values for safe use in sed
    local FROM_SUBNET_ESCAPED=${FROM_SUBNET//./\\.}
    local TO_SUBNET_ESCAPED=${TO_SUBNET//./\\.}
    
    log_info "Starting site change from subnet $FROM_SUBNET to $TO_SUBNET"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN MODE - No changes will be applied"
    else
        check_root
    fi
    
    # Update Network Manager connections
    check_nm
    update_nm_connections "$FROM_SUBNET" "$TO_SUBNET" "$DRY_RUN"
    
    # Update /etc/hosts file
    update_hosts_file "$FROM_SUBNET_ESCAPED" "$TO_SUBNET_ESCAPED" "$DRY_RUN"
    
    # Update Pacemaker if requested
    if [ "$UPDATE_PACEMAKER" = true ]; then
        update_pacemaker "$FROM_SUBNET_ESCAPED" "$TO_SUBNET_ESCAPED" "$DRY_RUN"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "Dry run completed - no changes were applied"
    else
        log_success "Site change completed successfully"
    fi
}

# Run the script
main "$@"