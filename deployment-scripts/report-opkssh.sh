#!/bin/bash
#
# opkssh Installation Reporter
# Analyzes existing opkssh installations and reports to tracker server
#
# Requirements: curl, bash
# Usage: ./report-opkssh.sh
#

set -e

# Get script directory for finding .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env file if it exists
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
fi

# Configuration from .env or defaults
TRACKER_URL="${TRACKER_URL:-}"
TRACKER_USER="${TRACKER_USER:-}"
TRACKER_PASS="${TRACKER_PASS:-}"
SSH_AGENT="${SSH_AGENT:-true}"
HOST_ALIAS=""
FORCE_STATUS=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Analyze existing opkssh installation and report to tracker server.

Options:
    --tracker-url URL       URL of the deployment tracking server
    --tracker-user USER     Username for tracker basic auth
    --tracker-pass PASS     Password for tracker basic auth
    --alias ALIAS           Friendly alias for this host (used in SSH config)
    --status STATUS         Override status (success/incomplete/failed)
    --ssh-agent             Enable SSH agent forwarding in SSH config (default: true)
    --no-ssh-agent          Disable SSH agent forwarding in SSH config
    --dry-run               Show what would be reported without sending
    --help                  Show this help message

EOF
    exit 0
}

# Parse arguments
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --tracker-url)
            TRACKER_URL="$2"
            shift 2
            ;;
        --tracker-user)
            TRACKER_USER="$2"
            shift 2
            ;;
        --tracker-pass)
            TRACKER_PASS="$2"
            shift 2
            ;;
        --alias)
            HOST_ALIAS="$2"
            shift 2
            ;;
        --status)
            FORCE_STATUS="$2"
            shift 2
            ;;
        --ssh-agent)
            SSH_AGENT="true"
            shift
            ;;
        --no-ssh-agent)
            SSH_AGENT="false"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_usage
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            ;;
    esac
done

# Check if opkssh is installed
check_opkssh() {
    if ! command -v opkssh &> /dev/null; then
        log_error "opkssh is not installed on this system"
        exit 1
    fi
    log_info "opkssh found: $(which opkssh)"
}

# Gather system information
gather_info() {
    log_info "Gathering system information..."

    # Hostname
    HOSTNAME_INFO=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "unknown")

    # IP address
    IP_INFO=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9.]+' || \
              hostname -I 2>/dev/null | awk '{print $1}' || \
              echo "unknown")

    # OS information
    if [[ -f /etc/os-release ]]; then
        OS_INFO=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
    else
        OS_INFO="Linux $(uname -r)"
    fi

    # opkssh version
    OPKSSH_VERSION=$(opkssh --version 2>/dev/null || echo "unknown")

    # Get configured user from /etc/opk/auth_id
    CONFIGURED_USER="unknown"
    if [[ -f /etc/opk/auth_id ]]; then
        # auth_id format: <principal> <email> <issuer>
        # Get the first principal (usually root or pi)
        CONFIGURED_USER=$(head -n1 /etc/opk/auth_id 2>/dev/null | awk '{print $1}' || echo "unknown")
    fi

    log_info "Hostname: $HOSTNAME_INFO"
    log_info "IP Address: $IP_INFO"
    log_info "OS: $OS_INFO"
    log_info "opkssh Version: $OPKSSH_VERSION"
    log_info "Configured User: $CONFIGURED_USER"
}

# Check opkssh configuration
check_config() {
    log_info "Checking opkssh configuration..."

    local status="success"
    local issues=""

    # Check if /etc/opk directory exists
    if [[ ! -d /etc/opk ]]; then
        status="incomplete"
        issues="Missing /etc/opk directory"
    fi

    # Check providers file
    if [[ ! -f /etc/opk/providers ]]; then
        status="incomplete"
        issues="${issues:+$issues; }Missing providers file"
    else
        local provider_count=$(wc -l < /etc/opk/providers 2>/dev/null || echo 0)
        log_info "Providers configured: $provider_count"
    fi

    # Check auth_id file
    if [[ ! -f /etc/opk/auth_id ]]; then
        status="incomplete"
        issues="${issues:+$issues; }Missing auth_id file"
    else
        local user_count=$(wc -l < /etc/opk/auth_id 2>/dev/null || echo 0)
        log_info "Users configured: $user_count"
    fi

    # Check sshd config - opkssh uses /etc/ssh/sshd_config.d/60-opk-ssh.conf
    local sshd_configured=false
    local sshd_config_location=""

    if [[ -f /etc/ssh/sshd_config.d/60-opk-ssh.conf ]]; then
        sshd_configured=true
        sshd_config_location="/etc/ssh/sshd_config.d/60-opk-ssh.conf"
    elif grep -q "AuthorizedKeysCommand.*opkssh" /etc/ssh/sshd_config 2>/dev/null; then
        sshd_configured=true
        sshd_config_location="/etc/ssh/sshd_config"
    elif grep -rq "AuthorizedKeysCommand.*opkssh" /etc/ssh/sshd_config.d/ 2>/dev/null; then
        sshd_configured=true
        sshd_config_location="/etc/ssh/sshd_config.d/"
    fi

    if [[ "$sshd_configured" == true ]]; then
        log_info "SSHD configured: Yes ($sshd_config_location)"
    else
        status="incomplete"
        issues="${issues:+$issues; }SSHD not configured for opkssh"
        log_warn "SSHD not configured for opkssh (expected: /etc/ssh/sshd_config.d/60-opk-ssh.conf)"
    fi

    # Override status if --status was provided
    if [[ -n "$FORCE_STATUS" ]]; then
        log_info "Overriding status with: $FORCE_STATUS"
        status="$FORCE_STATUS"
        issues=""
    fi

    INSTALL_STATUS="$status"
    INSTALL_ISSUES="$issues"
}

# Report to tracker
report_to_tracker() {
    if [[ -z "$TRACKER_URL" ]]; then
        log_warn "No tracker URL configured - skipping report"
        return 0
    fi

    log_info "Reporting to tracker..."

    # Build JSON payload
    local alias_field=""
    if [[ -n "$HOST_ALIAS" ]]; then
        alias_field="\"alias\": \"${HOST_ALIAS}\","
    fi

    # Convert SSH_AGENT string to JSON boolean
    local ssh_agent_bool="false"
    if [[ "$SSH_AGENT" == "true" ]]; then
        ssh_agent_bool="true"
    fi

    local json_payload=$(cat << EOF
{
    "hostname": "${HOSTNAME_INFO}",
    ${alias_field}
    "ip": "${IP_INFO}",
    "user": "${CONFIGURED_USER}",
    "status": "${INSTALL_STATUS}",
    "opkssh_version": "${OPKSSH_VERSION}",
    "os_info": "${OS_INFO}",
    "ssh_agent": ${ssh_agent_bool},
    "error": "${INSTALL_ISSUES}"
}
EOF
)

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo "=== DRY RUN - Would send the following report ==="
        echo "$json_payload"
        echo ""
        return 0
    fi

    # Build auth options
    local auth_opts=""
    if [[ -n "$TRACKER_USER" && -n "$TRACKER_PASS" ]]; then
        auth_opts="-u ${TRACKER_USER}:${TRACKER_PASS}"
    fi

    # Send report
    local response
    local http_code

    response=$(curl -s -w "\n%{http_code}" -X POST "${TRACKER_URL}/report" \
        $auth_opts \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        --connect-timeout 10 \
        --max-time 30 2>&1) || true

    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
        log_info "Report sent successfully"
    elif [[ "$http_code" == "401" ]]; then
        log_error "Authentication failed - check tracker credentials"
        return 1
    else
        log_error "Failed to send report (HTTP $http_code)"
        log_error "Response: $response"
        return 1
    fi
}

# Show summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "  opkssh Installation Report"
    echo "=========================================="
    echo ""
    echo "System:"
    echo "  Hostname: $HOSTNAME_INFO"
    if [[ -n "$HOST_ALIAS" ]]; then
        echo "  Alias:    $HOST_ALIAS"
    fi
    echo "  IP:       $IP_INFO"
    echo "  OS:       $OS_INFO"
    echo ""
    echo "opkssh:"
    echo "  Version:  $OPKSSH_VERSION"
    echo "  User:     $CONFIGURED_USER"
    echo "  Status:   $INSTALL_STATUS"
    if [[ -n "$INSTALL_ISSUES" ]]; then
        echo "  Issues:   $INSTALL_ISSUES"
    fi
    echo ""
}

# Main
main() {
    echo "=========================================="
    echo "  opkssh Installation Reporter"
    echo "=========================================="
    echo ""

    check_opkssh
    gather_info
    check_config
    show_summary
    report_to_tracker

    log_info "Done!"
}

main "$@"
