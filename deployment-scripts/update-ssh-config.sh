#!/bin/bash
#
# SSH Config Updater
# Fetches deployment data from the tracker and updates ~/.ssh/config
#
# Usage: ./update-ssh-config.sh --tracker-url http://tracker:8080
#

set -e

# Get script directory for finding .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env file if it exists (from same directory as script)
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
fi

# Configuration - Tracker server (can be set in .env file or overridden via command line)
TRACKER_URL="${TRACKER_URL:-}"
TRACKER_USER="${TRACKER_USER:-}"
TRACKER_PASS="${TRACKER_PASS:-}"
SSH_CONFIG_FILE="$HOME/.ssh/config"
BACKUP_CONFIG=true
PREFIX=""
IDENTITY_FILE="~/.ssh/id_ecdsa"
MARKER_START="# === OPKSSH MANAGED HOSTS START ==="
MARKER_END="# === OPKSSH MANAGED HOSTS END ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Fetch SSH config from the opkssh deployment tracker and update ~/.ssh/config

Options:
    --tracker-url URL     URL of the deployment tracking server (required)
    --tracker-user USER   Username for tracker basic auth (if auth is enabled)
    --tracker-pass PASS   Password for tracker basic auth (if auth is enabled)
    --config FILE         SSH config file to update (default: ~/.ssh/config)
    --prefix PREFIX       Prefix for host aliases (e.g., "opk-" -> "opk-hostname")
    --identity-file FILE  SSH identity file path (default: ~/.ssh/id_ecdsa)
    --no-backup           Don't create backup of existing config
    --dry-run             Show what would be added without modifying config
    --help                Show this help message

Examples:
    # Update SSH config from tracker
    $0 --tracker-url http://tracker:8080

    # With basic auth
    $0 --tracker-url http://tracker:8080 --tracker-user admin --tracker-pass secret

    # With custom prefix and identity file
    $0 --tracker-url http://tracker:8080 --prefix "opk-" --identity-file ~/.ssh/opk_key

    # Preview changes without applying
    $0 --tracker-url http://tracker:8080 --dry-run

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
        --config)
            SSH_CONFIG_FILE="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --identity-file)
            IDENTITY_FILE="$2"
            shift 2
            ;;
        --no-backup)
            BACKUP_CONFIG=false
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

# Validate required arguments
if [[ -z "$TRACKER_URL" ]]; then
    log_error "Missing required argument: --tracker-url"
    show_usage
fi

# Ensure .ssh directory exists
mkdir -p "$(dirname "$SSH_CONFIG_FILE")"

# Fetch SSH config from tracker
log_info "Fetching SSH config from tracker..."

QUERY_PARAMS="identity_file=$(echo "$IDENTITY_FILE" | sed 's/~/%7E/g')"
if [[ -n "$PREFIX" ]]; then
    QUERY_PARAMS="${QUERY_PARAMS}&prefix=$PREFIX"
fi

# Build auth options if credentials provided
AUTH_OPTS=""
if [[ -n "$TRACKER_USER" && -n "$TRACKER_PASS" ]]; then
    AUTH_OPTS="-u ${TRACKER_USER}:${TRACKER_PASS}"
fi

NEW_CONFIG=$(curl -s $AUTH_OPTS "${TRACKER_URL}/ssh-config?${QUERY_PARAMS}" \
    --connect-timeout 10 \
    --max-time 30)

# Check for auth failure
if [[ "$NEW_CONFIG" == *"Invalid credentials"* || "$NEW_CONFIG" == *"401"* ]]; then
    log_error "Authentication failed - check --tracker-user and --tracker-pass"
    exit 1
fi

if [[ -z "$NEW_CONFIG" || "$NEW_CONFIG" == *"No successful deployments"* ]]; then
    log_warn "No deployments found on tracker"
    exit 0
fi

# Count hosts
HOST_COUNT=$(echo "$NEW_CONFIG" | grep -c "^Host " || echo 0)
log_info "Found $HOST_COUNT hosts from tracker"

# Prepare managed section
MANAGED_SECTION=$(cat << EOF
$MARKER_START
# Auto-generated from opkssh deployment tracker
# Last updated: $(date -Iseconds)
# Tracker: $TRACKER_URL

$NEW_CONFIG
$MARKER_END
EOF
)

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "=== DRY RUN - Would add the following to $SSH_CONFIG_FILE ==="
    echo ""
    echo "$MANAGED_SECTION"
    echo ""
    exit 0
fi

# Create backup if config exists
if [[ -f "$SSH_CONFIG_FILE" && "$BACKUP_CONFIG" == true ]]; then
    BACKUP_FILE="${SSH_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SSH_CONFIG_FILE" "$BACKUP_FILE"
    log_info "Created backup: $BACKUP_FILE"
fi

# Check if managed section already exists
if [[ -f "$SSH_CONFIG_FILE" ]] && grep -q "$MARKER_START" "$SSH_CONFIG_FILE"; then
    log_info "Updating existing managed section..."

    # Remove old managed section and add new one
    # Use awk to handle multi-line replacement
    TEMP_FILE=$(mktemp)
    awk -v start="$MARKER_START" -v end="$MARKER_END" -v new="$MANAGED_SECTION" '
        $0 ~ start { skip=1; printed=0 }
        $0 ~ end { skip=0; if(!printed) { print new; printed=1 } next }
        !skip { print }
        END { if(!printed) print new }
    ' "$SSH_CONFIG_FILE" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$SSH_CONFIG_FILE"
else
    log_info "Adding managed section to config..."

    # Append to existing config or create new one
    if [[ -f "$SSH_CONFIG_FILE" ]]; then
        echo "" >> "$SSH_CONFIG_FILE"
    fi
    echo "$MANAGED_SECTION" >> "$SSH_CONFIG_FILE"
fi

# Set proper permissions
chmod 600 "$SSH_CONFIG_FILE"

log_info "SSH config updated successfully!"
log_info "File: $SSH_CONFIG_FILE"
log_info "Hosts added: $HOST_COUNT"

echo ""
echo "You can now SSH to your deployed hosts using:"
echo "  ssh ${PREFIX}<hostname>"
echo ""
