#!/bin/bash
#
# opkssh Mass Deployment Script
# Deploys OpenPubkey SSH on Debian-based Linux systems
#
# Requirements: curl, sudo, bash
# Target: Debian-based Linux (Debian, Ubuntu, Raspberry Pi OS, etc.)
#
# Usage:
#   Interactive:     sudo ./deploy-opkssh.sh --tracker-url http://tracker:8080
#   Non-interactive: sudo ./deploy-opkssh.sh --tracker-url http://tracker:8080 --user root
#

set -e

# Configuration - OpenID Provider (must be set in .env file)
PROVIDER_ISSUER="${PROVIDER_ISSUER:-}"
PROVIDER_CLIENT_ID="${PROVIDER_CLIENT_ID:-}"
PROVIDER_EXPIRY="${PROVIDER_EXPIRY:-24h}"
USER_EMAIL="${USER_EMAIL:-}"

# Get script directory for finding .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env file if it exists (from same directory as script)
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
fi

# Configuration - Defaults (can be set in .env file or overridden via command line)
DEFAULT_PRINCIPAL="${DEFAULT_PRINCIPAL:-root}"
TRACKER_URL="${TRACKER_URL:-}"
TRACKER_USER="${TRACKER_USER:-}"
TRACKER_PASS="${TRACKER_PASS:-}"

PRINCIPAL=""
HOST_ALIAS=""
NON_INTERACTIVE=false

# Runtime info (populated during execution)
HOSTNAME_INFO=""
IP_INFO=""
OS_INFO=""
OPKSSH_VERSION=""
DEPLOYMENT_STATUS="success"
DEPLOYMENT_ERROR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy opkssh on Debian-based Linux systems with automatic tracking.

Options:
    --tracker-url URL       URL of the deployment tracking server (required for reporting)
                            Example: http://tracker.example.com:8080
    --tracker-user USER     Username for tracker basic auth (if auth is enabled)
    --tracker-pass PASS     Password for tracker basic auth (if auth is enabled)
    --user USERNAME         Local username/principal for SSH access (default: root)
                            Use this for non-interactive deployments
    --alias ALIAS           Friendly alias for this host (used in SSH config)
    --help                  Show this help message

Examples:
    # Interactive mode (prompts for username)
    sudo $0 --tracker-url http://tracker:8080

    # With alias for SSH config
    sudo $0 --alias webserver-prod --user root

    # Non-interactive mode (for automation)
    sudo $0 --tracker-url http://tracker:8080 --user root --alias db-server

    # Without tracking (local deployment only)
    sudo $0 --user pi --alias raspberry-pi-kitchen

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
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
            --user)
                PRINCIPAL="$2"
                NON_INTERACTIVE=true
                shift 2
                ;;
            --alias)
                HOST_ALIAS="$2"
                shift 2
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
}

# Gather system information
gather_system_info() {
    log_info "Gathering system information..."

    # Hostname
    HOSTNAME_INFO=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "unknown")

    # IP address - try to get the primary IP (not localhost)
    IP_INFO=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9.]+' || \
              hostname -I 2>/dev/null | awk '{print $1}' || \
              echo "unknown")

    # OS information
    if [[ -f /etc/os-release ]]; then
        OS_INFO=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
    else
        OS_INFO="Debian $(cat /etc/debian_version 2>/dev/null || echo 'unknown')"
    fi

    log_info "Hostname: $HOSTNAME_INFO"
    log_info "IP Address: $IP_INFO"
    log_info "OS: $OS_INFO"
}

# Report deployment status to tracking server
report_deployment() {
    if [[ -z "$TRACKER_URL" ]]; then
        log_info "No tracker URL configured - skipping deployment report"
        return 0
    fi

    log_info "Reporting deployment status to tracker..."

    # Get opkssh version if installed
    OPKSSH_VERSION=$(opkssh --version 2>/dev/null || echo "unknown")

    # Build JSON payload
    local alias_field=""
    if [[ -n "$HOST_ALIAS" ]]; then
        alias_field="\"alias\": \"${HOST_ALIAS}\","
    fi

    local json_payload=$(cat << EOF
{
    "hostname": "${HOSTNAME_INFO}",
    ${alias_field}
    "ip": "${IP_INFO}",
    "user": "${PRINCIPAL}",
    "status": "${DEPLOYMENT_STATUS}",
    "opkssh_version": "${OPKSSH_VERSION}",
    "os_info": "${OS_INFO}",
    "error": "${DEPLOYMENT_ERROR}"
}
EOF
)

    # Send report to tracker
    local response
    local http_code
    local auth_opts=""

    # Add basic auth if credentials provided
    if [[ -n "$TRACKER_USER" && -n "$TRACKER_PASS" ]]; then
        auth_opts="-u ${TRACKER_USER}:${TRACKER_PASS}"
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "${TRACKER_URL}/report" \
        $auth_opts \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        --connect-timeout 10 \
        --max-time 30 2>&1) || true

    # Extract HTTP status code (last line)
    http_code=$(echo "$response" | tail -n1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
        log_info "Deployment report sent successfully"
    elif [[ "$http_code" == "401" ]]; then
        log_warn "Authentication failed - check --tracker-user and --tracker-pass"
    else
        log_warn "Failed to send deployment report (HTTP $http_code)"
        log_warn "Response: $response"
    fi
}

# Error handler - report failure before exit
handle_error() {
    local exit_code=$?
    local line_number=$1

    DEPLOYMENT_STATUS="failed"
    DEPLOYMENT_ERROR="Script failed at line $line_number with exit code $exit_code"

    log_error "Deployment failed at line $line_number"

    # Try to report failure
    report_deployment

    exit $exit_code
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check for required commands
check_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=()

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v sudo &> /dev/null; then
        missing_deps+=("sudo")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Install them with: apt-get install ${missing_deps[*]}"
        exit 1
    fi

    log_info "All dependencies satisfied"
}

# Check if running on Debian-based system
check_debian() {
    log_info "Checking operating system..."

    if [[ ! -f /etc/debian_version ]]; then
        log_error "This script is designed for Debian-based systems only"
        log_error "Detected: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 || echo 'Unknown')"
        exit 1
    fi

    local distro=$(cat /etc/os-release 2>/dev/null | grep "^ID=" | cut -d= -f2 | tr -d '"')
    local version=$(cat /etc/debian_version 2>/dev/null || echo "unknown")
    log_info "Detected Debian-based system: $distro (version: $version)"
}

# Check SSH server is installed
check_sshd() {
    log_info "Checking SSH server..."

    if ! command -v sshd &> /dev/null; then
        log_error "OpenSSH server (sshd) is not installed"
        log_info "Install it with: apt-get install openssh-server"
        exit 1
    fi

    log_info "SSH server found"
}

# Validate required configuration
check_config() {
    log_info "Validating configuration..."

    local missing_vars=()

    if [[ -z "$PROVIDER_ISSUER" ]]; then
        missing_vars+=("PROVIDER_ISSUER")
    fi

    if [[ -z "$PROVIDER_CLIENT_ID" ]]; then
        missing_vars+=("PROVIDER_CLIENT_ID")
    fi

    if [[ -z "$USER_EMAIL" ]]; then
        missing_vars+=("USER_EMAIL")
    fi

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required configuration variables: ${missing_vars[*]}"
        log_error "Please set these variables in the .env file"
        log_info "Copy .env.example to .env and configure your OpenID provider settings"
        exit 1
    fi

    log_info "Configuration validated successfully"
    log_info "Provider: $PROVIDER_ISSUER"
    log_info "User Email: $USER_EMAIL"
}

# Prompt for principal (username) - interactive mode only
get_principal() {
    # If already set via command line, validate and return
    if [[ -n "$PRINCIPAL" ]]; then
        log_info "Using specified username: $PRINCIPAL"
        if ! id "$PRINCIPAL" &>/dev/null; then
            if [[ "$NON_INTERACTIVE" == true ]]; then
                log_warn "User '$PRINCIPAL' does not exist on this system - continuing anyway"
            else
                log_warn "User '$PRINCIPAL' does not exist on this system"
                read -p "Continue anyway? [y/N]: " confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    log_error "Aborted by user"
                    exit 1
                fi
            fi
        fi
        return 0
    fi

    echo ""
    echo "=========================================="
    echo "  User Configuration"
    echo "=========================================="
    echo ""
    echo "Enter the local username (principal) that should be"
    echo "authorized for SSH access with the identity:"
    echo "  Email: $USER_EMAIL"
    echo "  Provider: $PROVIDER_ISSUER"
    echo ""
    echo "Common values:"
    echo "  - root (default for most systems)"
    echo "  - pi (default for Raspberry Pi)"
    echo "  - ubuntu (default for Ubuntu cloud images)"
    echo ""

    read -p "Enter username [$DEFAULT_PRINCIPAL]: " input_principal
    PRINCIPAL="${input_principal:-$DEFAULT_PRINCIPAL}"

    # Validate the user exists
    if ! id "$PRINCIPAL" &>/dev/null; then
        log_warn "User '$PRINCIPAL' does not exist on this system"
        read -p "Continue anyway? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_error "Aborted by user"
            exit 1
        fi
    fi

    log_info "Will configure SSH access for user: $PRINCIPAL"
}

# Install opkssh using official installer
install_opkssh() {
    log_info "Installing opkssh..."

    # Check if already installed
    if command -v opkssh &> /dev/null; then
        local current_version=$(opkssh --version 2>/dev/null || echo "unknown")
        log_warn "opkssh is already installed (version: $current_version)"

        if [[ "$NON_INTERACTIVE" == true ]]; then
            log_info "Non-interactive mode: reinstalling opkssh"
        else
            read -p "Reinstall/update opkssh? [y/N]: " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                log_info "Skipping opkssh installation"
                return 0
            fi
        fi
    fi

    # Download and run official installer
    log_info "Downloading and running official opkssh installer..."

    curl -fsSL "https://raw.githubusercontent.com/openpubkey/opkssh/main/scripts/install-linux.sh" -o /tmp/install-opkssh.sh

    if [[ ! -f /tmp/install-opkssh.sh ]]; then
        log_error "Failed to download opkssh installer"
        exit 1
    fi

    chmod +x /tmp/install-opkssh.sh
    bash /tmp/install-opkssh.sh

    # Cleanup
    rm -f /tmp/install-opkssh.sh

    # Verify installation
    if ! command -v opkssh &> /dev/null; then
        log_error "opkssh installation failed - binary not found"
        exit 1
    fi

    log_info "opkssh installed successfully"
}

# Add custom provider to /etc/opk/providers
add_provider() {
    log_info "Configuring custom OpenID provider..."

    local providers_file="/etc/opk/providers"
    local provider_line="$PROVIDER_ISSUER $PROVIDER_CLIENT_ID $PROVIDER_EXPIRY"

    # Ensure directory exists
    if [[ ! -d /etc/opk ]]; then
        log_error "/etc/opk directory does not exist - opkssh may not be installed correctly"
        exit 1
    fi

    # Check if provider already exists
    if [[ -f "$providers_file" ]] && grep -qF "$PROVIDER_ISSUER" "$providers_file"; then
        log_warn "Provider $PROVIDER_ISSUER already exists in $providers_file"
        log_info "Updating existing provider entry..."
        # Remove old entry and add new one
        sed -i "\|$PROVIDER_ISSUER|d" "$providers_file"
    fi

    # Add provider
    echo "$provider_line" >> "$providers_file"

    log_info "Added provider to $providers_file:"
    log_info "  Issuer: $PROVIDER_ISSUER"
    log_info "  Client ID: $PROVIDER_CLIENT_ID"
    log_info "  Expiry: $PROVIDER_EXPIRY"
}

# Add user authorization
add_user() {
    log_info "Adding user authorization..."

    # Use opkssh add command
    opkssh add "$PRINCIPAL" "$USER_EMAIL" "$PROVIDER_ISSUER"

    log_info "Added user authorization:"
    log_info "  Principal: $PRINCIPAL"
    log_info "  Email: $USER_EMAIL"
    log_info "  Issuer: $PROVIDER_ISSUER"
}

# Restart SSH service
restart_sshd() {
    log_info "Restarting SSH service..."

    if systemctl is-active --quiet sshd; then
        systemctl restart sshd
        log_info "SSH service (sshd) restarted"
    elif systemctl is-active --quiet ssh; then
        systemctl restart ssh
        log_info "SSH service (ssh) restarted"
    else
        log_warn "Could not determine SSH service name - please restart manually"
    fi
}

# Show summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "  Deployment Complete"
    echo "=========================================="
    echo ""
    echo "Host Information:"
    echo "  Hostname: $HOSTNAME_INFO"
    if [[ -n "$HOST_ALIAS" ]]; then
        echo "  Alias:    $HOST_ALIAS"
    fi
    echo "  IP:       $IP_INFO"
    echo "  OS:       $OS_INFO"
    echo ""
    echo "opkssh has been installed and configured with:"
    echo ""
    echo "Provider:"
    echo "  Issuer:    $PROVIDER_ISSUER"
    echo "  Client ID: $PROVIDER_CLIENT_ID"
    echo "  Expiry:    $PROVIDER_EXPIRY"
    echo ""
    echo "User Authorization:"
    echo "  Principal: $PRINCIPAL"
    echo "  Email:     $USER_EMAIL"
    echo "  Issuer:    $PROVIDER_ISSUER"
    echo ""
    echo "Configuration files:"
    echo "  /etc/opk/providers  - OpenID providers"
    echo "  /etc/opk/auth_id    - User authorizations"
    echo ""
    if [[ -n "$TRACKER_URL" ]]; then
        echo "Tracking:"
        echo "  Server:   $TRACKER_URL"
        echo "  Status:   $DEPLOYMENT_STATUS"
        echo ""
    fi
    echo "To login from a client, run:"
    echo "  opkssh login --provider=\"$PROVIDER_ISSUER,$PROVIDER_CLIENT_ID\""
    echo ""
    echo "Then SSH as usual:"
    echo "  ssh $PRINCIPAL@$HOSTNAME_INFO"
    echo ""
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"

    echo "=========================================="
    echo "  opkssh Deployment Script"
    echo "=========================================="
    echo ""

    # Set up error handler
    trap 'handle_error $LINENO' ERR

    # Pre-flight checks
    check_root
    check_dependencies
    check_debian
    check_sshd
    check_config

    # Gather system info early (needed for error reporting)
    gather_system_info

    # Get user input
    get_principal

    echo ""
    echo "=========================================="
    echo "  Starting Installation"
    echo "=========================================="
    echo ""

    # Installation steps
    install_opkssh
    add_provider
    add_user
    restart_sshd

    # Mark as successful
    DEPLOYMENT_STATUS="success"

    # Report to tracker
    report_deployment

    # Done
    show_summary
}

# Run main function
main "$@"
