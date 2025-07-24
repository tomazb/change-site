#!/bin/bash

# Simple test script to debug the configuration issue
set -euo pipefail

echo "Debug: Starting script"

# Test configuration loading
CONFIG_FILE=""
DEFAULT_CONFIG_PATHS=(
    "./change-site.conf"
    "/etc/change-site/change-site.conf"
    "$HOME/.config/change-site/change-site.conf"
    "$HOME/.change-site.conf"
)

declare -A SUBNET_PAIRS

find_config_file() {
    echo "Debug: Looking for config file"
    
    # Search default locations
    local config_path
    for config_path in "${DEFAULT_CONFIG_PATHS[@]}"; do
        echo "Debug: Checking $config_path"
        if [[ -f "$config_path" ]]; then
            echo "Debug: Found config at $config_path"
            echo "$config_path"
            return 0
        fi
    done
    
    echo "Debug: No config file found"
    return 1
}

parse_config_line() {
    local line="$1"
    
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && return 0
    [[ "$line" =~ ^[[:space:]]*$ ]] && return 0
    
    # Parse key=value pairs
    if [[ "$line" =~ ^[[:space:]]*([^=]+)=(.*)$ ]]; then
        local key="${BASH_REMATCH[1]// /}"
        local value="${BASH_REMATCH[2]}"
        echo "CONFIG:$key:$value"
        return 0
    fi
    
    return 0
}

apply_config_setting() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        SUBNET_PAIR_*)
            local pair_name="${key#SUBNET_PAIR_}"
            SUBNET_PAIRS["$pair_name"]="$value"
            echo "Debug: Added subnet pair $pair_name = $value"
            ;;
        *)
            echo "Debug: Skipping config key: $key"
            ;;
    esac
}

load_configuration() {
    echo "Debug: Starting configuration load"
    local config_file
    config_file="$(find_config_file)" || {
        echo "Debug: No configuration file found, using defaults"
        return 0
    }
    
    echo "Debug: Loading configuration from: $config_file"
    
    local line
    while IFS= read -r line; do
        local parsed
        parsed="$(parse_config_line "$line")"
        
        if [[ "$parsed" == CONFIG:* ]]; then
            local key="${parsed#CONFIG:}"
            key="${key%%:*}"
            local value="${parsed#CONFIG:*:}"
            apply_config_setting "$key" "$value"
        fi
    done < "$config_file"
    
    echo "Debug: Configuration loaded successfully"
}

list_subnet_pairs() {
    echo "Debug: Listing subnet pairs"
    if [[ ${#SUBNET_PAIRS[@]} -eq 0 ]]; then
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

# Main execution
echo "Debug: About to load configuration"
load_configuration
echo "Debug: About to list pairs"
list_subnet_pairs
echo "Debug: Script completed successfully"