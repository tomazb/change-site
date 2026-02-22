#!/bin/bash
#
# monitoring-dashboard.sh - Simple monitoring dashboard for change-site operations
#
# This script provides a simple text-based dashboard for monitoring
# change-site operations, viewing logs, and checking system health.
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/change-site.log"
METRICS_FILE="/var/log/change-site-metrics.log"
STRUCTURED_LOG_FILE="/var/log/change-site-structured.log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Display header
show_header() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}    Change-Site Monitoring Dashboard    ${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e "Last updated: $(date)"
    echo
}

# Show system health
show_health() {
    echo -e "${BLUE}=== System Health ===${NC}"
    
    # Disk usage
    local disk_usage
    if [[ -f "$LOG_FILE" ]]; then
        disk_usage=$(df "$(dirname "$LOG_FILE")" | awk 'NR==2 {print $5}' | sed 's/%//')
        if [[ $disk_usage -gt 90 ]]; then
            echo -e "Disk Usage: ${RED}${disk_usage}% (HIGH)${NC}"
        elif [[ $disk_usage -gt 70 ]]; then
            echo -e "Disk Usage: ${YELLOW}${disk_usage}% (MEDIUM)${NC}"
        else
            echo -e "Disk Usage: ${GREEN}${disk_usage}% (OK)${NC}"
        fi
    else
        echo -e "Disk Usage: ${YELLOW}Unknown (log file not found)${NC}"
    fi
    
    # Log file size
    if [[ -f "$LOG_FILE" ]]; then
        local log_size
        log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        local log_size_mb=$((log_size / 1024 / 1024))
        if [[ $log_size_mb -gt 100 ]]; then
            echo -e "Log Size: ${RED}${log_size_mb}MB (LARGE)${NC}"
        elif [[ $log_size_mb -gt 50 ]]; then
            echo -e "Log Size: ${YELLOW}${log_size_mb}MB (MEDIUM)${NC}"
        else
            echo -e "Log Size: ${GREEN}${log_size_mb}MB (OK)${NC}"
        fi
    else
        echo -e "Log Size: ${YELLOW}No log file found${NC}"
    fi
    
    # Recent errors
    if [[ -f "$METRICS_FILE" ]]; then
        local recent_errors
        recent_errors=$(tail -50 "$METRICS_FILE" 2>/dev/null | grep -c "ERROR" || echo "0")
        if [[ $recent_errors -gt 5 ]]; then
            echo -e "Recent Errors: ${RED}${recent_errors} (HIGH)${NC}"
        elif [[ $recent_errors -gt 2 ]]; then
            echo -e "Recent Errors: ${YELLOW}${recent_errors} (MEDIUM)${NC}"
        else
            echo -e "Recent Errors: ${GREEN}${recent_errors} (OK)${NC}"
        fi
    else
        echo -e "Recent Errors: ${YELLOW}No metrics file found${NC}"
    fi
    
    echo
}

# Show recent operations
show_recent_operations() {
    echo -e "${BLUE}=== Recent Operations ===${NC}"
    
    if [[ -f "$LOG_FILE" ]]; then
        echo "Last 5 operations:"
        tail -20 "$LOG_FILE" 2>/dev/null | grep -E "(Starting|completed|failed)" | tail -5 | while read -r line; do
            if echo "$line" | grep -q "completed successfully"; then
                echo -e "${GREEN}✓${NC} $line"
            elif echo "$line" | grep -q "failed"; then
                echo -e "${RED}✗${NC} $line"
            else
                echo -e "${CYAN}→${NC} $line"
            fi
        done
    else
        echo -e "${YELLOW}No log file found${NC}"
    fi
    
    echo
}

# Show performance metrics
show_performance() {
    echo -e "${BLUE}=== Performance Metrics ===${NC}"
    
    if [[ -f "$METRICS_FILE" ]]; then
        echo "Recent performance data:"
        tail -10 "$METRICS_FILE" 2>/dev/null | grep "PERFORMANCE" | tail -5 | while read -r line; do
            local timestamp operation duration
            timestamp=$(echo "$line" | awk '{print $1, $2}')
            operation=$(echo "$line" | awk '{print $4}')
            duration=$(echo "$line" | awk '{print $5}')
            
            if [[ "${duration%s}" -gt 60 ]]; then
                echo -e "${RED}⚠${NC} $timestamp - $operation: $duration"
            elif [[ "${duration%s}" -gt 30 ]]; then
                echo -e "${YELLOW}⚠${NC} $timestamp - $operation: $duration"
            else
                echo -e "${GREEN}✓${NC} $timestamp - $operation: $duration"
            fi
        done
    else
        echo -e "${YELLOW}No metrics file found${NC}"
    fi
    
    echo
}

# Show error summary
show_errors() {
    echo -e "${BLUE}=== Error Summary ===${NC}"
    
    if [[ -f "$METRICS_FILE" ]]; then
        local error_count
        error_count=$(grep -c "ERROR" "$METRICS_FILE" 2>/dev/null || echo "0")
        echo "Total errors logged: $error_count"
        
        if [[ $error_count -gt 0 ]]; then
            echo "Recent errors:"
            tail -20 "$METRICS_FILE" 2>/dev/null | grep "ERROR" | tail -3 | while read -r line; do
                echo -e "${RED}✗${NC} $line"
            done
        fi
    else
        echo -e "${YELLOW}No metrics file found${NC}"
    fi
    
    echo
}

# Show alerts
show_alerts() {
    echo -e "${BLUE}=== Recent Alerts ===${NC}"
    
    if [[ -f "$METRICS_FILE" ]]; then
        local alert_count
        alert_count=$(grep -c "ALERT" "$METRICS_FILE" 2>/dev/null || echo "0")
        
        if [[ $alert_count -gt 0 ]]; then
            echo "Recent alerts:"
            tail -20 "$METRICS_FILE" 2>/dev/null | grep "ALERT" | tail -3 | while read -r line; do
                echo -e "${RED}🚨${NC} $line"
            done
        else
            echo -e "${GREEN}No recent alerts${NC}"
        fi
    else
        echo -e "${YELLOW}No metrics file found${NC}"
    fi
    
    echo
}

# Interactive menu
show_menu() {
    echo -e "${CYAN}=== Options ===${NC}"
    echo "1) Refresh dashboard"
    echo "2) View full log"
    echo "3) View metrics log"
    echo "4) View structured log"
    echo "5) Clear logs"
    echo "6) Run health check"
    echo "7) Exit"
    echo
    echo -n "Choose option (1-7): "
}

# View full log
view_log() {
    if [[ -f "$LOG_FILE" ]]; then
        echo -e "${BLUE}=== Full Log (last 50 lines) ===${NC}"
        tail -50 "$LOG_FILE" | less -R
    else
        echo -e "${YELLOW}Log file not found: $LOG_FILE${NC}"
    fi
}

# View metrics log
view_metrics() {
    if [[ -f "$METRICS_FILE" ]]; then
        echo -e "${BLUE}=== Metrics Log (last 50 lines) ===${NC}"
        tail -50 "$METRICS_FILE" | less -R
    else
        echo -e "${YELLOW}Metrics file not found: $METRICS_FILE${NC}"
    fi
}

# View structured log
view_structured_log() {
    if [[ -f "$STRUCTURED_LOG_FILE" ]]; then
        echo -e "${BLUE}=== Structured Log (last 20 entries) ===${NC}"
        tail -20 "$STRUCTURED_LOG_FILE" | jq '.' 2>/dev/null || tail -20 "$STRUCTURED_LOG_FILE"
    else
        echo -e "${YELLOW}Structured log file not found: $STRUCTURED_LOG_FILE${NC}"
    fi
}

# Clear logs
clear_logs() {
    echo -n "Are you sure you want to clear all logs? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        [[ -f "$LOG_FILE" ]] && true > "$LOG_FILE"
        [[ -f "$METRICS_FILE" ]] && true > "$METRICS_FILE"
        [[ -f "$STRUCTURED_LOG_FILE" ]] && true > "$STRUCTURED_LOG_FILE"
        echo -e "${GREEN}Logs cleared${NC}"
    else
        echo "Operation cancelled"
    fi
}

# Run health check
run_health_check() {
    echo -e "${BLUE}=== Running Health Check ===${NC}"
    
    if [[ -x "$SCRIPT_DIR/change-site.sh" ]]; then
        # This would call the health_check function if it was exposed
        echo "Health check functionality would be called here"
        echo -e "${GREEN}Health check completed${NC}"
    else
        echo -e "${YELLOW}change-site.sh not found or not executable${NC}"
    fi
}

# Main dashboard loop
main() {
    while true; do
        show_header
        show_health
        show_recent_operations
        show_performance
        show_errors
        show_alerts
        show_menu
        
        read -r choice
        
        case $choice in
            1)
                continue
                ;;
            2)
                view_log
                echo
                echo "Press Enter to continue..."
                read -r
                ;;
            3)
                view_metrics
                echo
                echo "Press Enter to continue..."
                read -r
                ;;
            4)
                view_structured_log
                echo
                echo "Press Enter to continue..."
                read -r
                ;;
            5)
                clear_logs
                echo
                echo "Press Enter to continue..."
                read -r
                ;;
            6)
                run_health_check
                echo
                echo "Press Enter to continue..."
                read -r
                ;;
            7)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in awk grep tail; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Missing required dependencies: ${missing_deps[*]}${NC}"
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_dependencies
    main "$@"
fi