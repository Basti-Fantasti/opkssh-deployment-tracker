# opkssh Deployment Tracker

A comprehensive system for managing and tracking OpenPubkey SSH (opkssh) deployments across multiple Linux hosts.

> **Disclaimer**
> This project is not affiliated with the official opkssh or pocket-id projects. It is an independent tool designed to facilitate the deployment and management of opkssh installations.


## Overview

This system consists of:

- **Tracking Server** - A centralized FastAPI server that tracks opkssh deployments via HTTP API
- **Deployment Scripts** - Automated bash scripts for deploying opkssh to remote Linux hosts
- **Client Utilities** - Tools for reporting status and generating SSH configurations

## About the Required Projects

This deployment tracker depends on two awesome open-source projects:

### 🔐 opkssh - OpenPubkey SSH

[**opkssh**](https://github.com/openpubkey/opkssh) is a SSH authentication system that eliminates the need for traditional SSH keys by leveraging OpenID Connect (OIDC) for authentication. Instead of managing SSH key pairs, users authenticate with their existing OIDC provider (like Google, Microsoft, or self-hosted solutions), and opkssh automatically generates cryptographic proofs that authorize SSH access.

**Why opkssh?**
- ✅ **No SSH key management** - No more lost keys, key rotation headaches, or distributing public keys
- ✅ **Centralized identity** - Use your existing OIDC provider for authentication
- ✅ **Enhanced security** - Cryptographic proofs based on modern OIDC standards
- ✅ **Audit trail** - Every SSH connection is tied to a verified identity
- ✅ **Easy revocation** - Disable access by removing OIDC permissions, no need to update authorized_keys files

Learn more: [github.com/openpubkey/opkssh](https://github.com/openpubkey/opkssh)

### 🆔 Pocket ID - Self-Hosted OIDC Provider

[**Pocket ID**](https://github.com/pocket-id/pocket-id) is a lightweight, self-hosted OpenID Connect (OIDC) provider that gives you complete control over your authentication infrastructure. Perfect for homelab enthusiasts, small businesses, and anyone who wants to avoid vendor lock-in with cloud identity providers.

**Why Pocket ID?**
- ✅ **Self-hosted** - Full control over your identity provider, no third-party dependencies
- ✅ **Privacy-focused** - Your authentication data stays on your infrastructure
- ✅ **Easy setup** - Docker-based deployment with minimal configuration
- ✅ **Standards-compliant** - Full OIDC implementation compatible with any OIDC-aware application
- ✅ **Passkey Only** - Use Passkeys for authentication instead of Passwords
- ✅ **Perfect for opkssh** - Designed to work seamlessly with modern authentication systems
- ✅ **No vendor lock-in** - Own your identity infrastructure

Learn more: [github.com/pocket-id/pocket-id](https://github.com/pocket-id/pocket-id)

### How They Work Together

This deployment tracker integrates these technologies to provide a complete SSH management solution:

1. **Pocket ID** (or any OIDC provider) handles user authentication
2. **opkssh** uses OIDC tokens to authorize SSH connections without traditional keys
3. **This tracker** helps you deploy and manage opkssh across your infrastructure

The result? Secure, modern SSH authentication without the hassle of key management!

## Table of Contents

- [About the Required Projects](#about-the-required-projects)
- [Server Setup](#server-setup)
- [Web Dashboard](#web-dashboard)
  - [Main Dashboard Overview](#main-dashboard-overview)
  - [Deployment Grouping](#deployment-grouping)
  - [Bootstrap Deployment Feature](#bootstrap-deployment-feature)
  - [Deployment Management](#deployment-management)
  - [SSH Config Generator](#ssh-config-generator)
  - [API Documentation](#api-documentation)
- [Client Scripts Usage](#client-scripts-usage)
- [Configuration](#configuration)
- [OIDC Authentication Setup](#oidc-authentication-setup)
- [Upgrading from Previous Versions](#upgrading-from-previous-versions)
- [API Endpoints](#api-endpoints)
- [Troubleshooting](#troubleshooting)

---

## Changes

Latest changes can be found in the [Changelog](CHANGELOG.md)

## Server Setup

The tracking server runs as a Docker container using a pre-built image.

### Prerequisites

- Docker and Docker Compose installed
- A Linux host or server to run the tracker
- Ports: 8080 (or your chosen port) available
- OIDC Provider for authentication (e.g. Pocket ID, Auth0, Keycloak)
  Required OIDC details:
  - Issuer URL
  - Client ID
  - Expiry duration
- Account on your OIDC provider for authentication


### Quick Start

1. **Checkout this repository:**
   ```bash
   git clone git@github.com:Basti-Fantasti/opkssh-deployment-tracker.git
   cd opkssh-deployment-tracker
   ```

2. **Create configuration file:**
   ```bash
   cp config.toml.example config.toml
   ```

3. **Edit the configuration:**
   ```bash
   nano config.toml  # or use your preferred editor
   ```

   **Important:** Change the default password!
   ```toml
   [auth]
   mode = "basic"  # Authentication mode: "none", "basic", or "oidc"
   username = "admin"
   password = "your-secure-password-here"  # CHANGE THIS!
   ```

4. **Create data directory:**
   ```bash
   mkdir -p data
   ```

5. **Start the server:**
   ```bash
   docker-compose up -d
   ```

6. **Verify the server is running:**
   ```bash
   docker-compose logs -f
   ```

   Or check the health endpoint:
   ```bash
   curl http://localhost:8080/health
   ```

7. **Access the web dashboard:**
   Open your browser and navigate to: `http://your-server-ip:8080`

### Server Management

**View logs:**
```bash
docker-compose logs -f
```

**Stop the server:**
```bash
docker-compose down
```

**Restart the server:**
```bash
docker-compose restart
```

**Update to latest version:**
```bash
docker-compose pull
docker-compose up -d
```

---

## Web Dashboard

The opkssh Deployment Tracker provides a comprehensive web-based dashboard for managing your deployments. Access it at `http://your-server-ip:8080` after starting the server.

### Main Dashboard Overview

> **New in v0.9.0** — The dashboard and authentication pages were redesigned. A shared
> stylesheet replaces the per-page CSS, status is shown as colored pill badges, timestamps
> are formatted for readability, native browser pop-ups are replaced with non-blocking
> toasts and in-page dialogs, and the layout is now responsive on mobile. This is a visual
> update only — no configuration or API changes, and existing deployments are unaffected.

![Main Dashboard](images/opkssh-1.png)
![Main Dashboard](images/opkssh-1b.png)

The main dashboard provides:
- **Deployment Statistics** - Quick overview showing total deployments, successful deployments, and failed deployments
- **Deployment Table** - Comprehensive view of all tracked hosts with columns for:
  - Hostname (clickable to view deployment history)
  - Alias (friendly name for SSH config)
  - IP Address
  - SSH User
  - Group (colored badge, clickable for inline editing)
  - SSH-Agent forwarding status (toggle on/off per host)
  - Deployment Status (success/incomplete/failed)
  - Timestamp of last report
  - opkssh Version installed
  - Operating System information
  - Actions (Edit/Delete buttons)
- **Group Filter Dropdown** - Filter deployments by group
- **Manage Groups Button** - Access group management modal
- **Generate Bootstrap Command** button for one-command deployments
- **SSH Config Generator** with hostname/IP mode selection
- **API Endpoints** quick access links

![Dashboard with Deployments](images/opkssh-gui-added.png)

Once you have deployments tracked, the dashboard shows all deployment details in an organized table. The hostname is clickable to view the complete deployment history timeline for that host.

### Deployment Grouping

> **New in v0.7.0**

Organize your deployments into logical groups with visual distinction and filtering capabilities.

#### Group Assignment

- **Single group per deployment** - Each deployment can belong to one group (optional, defaults to "Ungrouped")
- **Implicit group creation** - Simply type a new group name to auto-create it
- **Bootstrap token support** - Pre-assign group when generating bootstrap commands
- **Inline editing** - Click the group badge in the table to quickly change a deployment's group

#### Group Management Modal

Access via the "Manage Groups" button in the dashboard header to:
- View all groups with deployment counts
- Rename groups (updates all associated deployments automatically)
- Delete groups (moves deployments to "Ungrouped")
- Customize group colors using the color picker
- Real-time updates without page reload

#### Dashboard Filtering

- **Group selector dropdown** in the dashboard header
- Filter deployments by specific group or view all
- Statistics cards update to show filtered counts
- Smooth transitions when switching between groups

#### SSH Config with Groups

When downloading SSH config:
- Select a specific group to generate config for only those deployments
- Group comments are included in the generated SSH config file
- API support: `GET /ssh-config?group=production`

### Bootstrap Deployment Feature

The bootstrap deployment feature enables one-command opkssh installation without manual script distribution or configuration files.

#### Generate Bootstrap Command

![Bootstrap Modal - Initial](images/opkssh-2-bootstrap.png)

Click the "Generate Bootstrap Command" button to open the bootstrap modal where you can:
- View the tracker URL (automatically populated)
- Select a **Group** for the deployment (with autocomplete from existing groups)
- Enable **Non-interactive mode** to pre-configure all deployment values for fully automated installation
- Generate a time-limited deployment token

![Bootstrap Modal - Generated](images/opkssh-3-bootstrap.png)

After clicking "Generate", you receive:
- A ready-to-use `curl | bash` command
- Token expiry countdown (default: 1 hour)
- One-click "Copy to Clipboard" functionality
- Option to regenerate the token
- Reusable token - use the same command on multiple servers within the expiry window

#### Bootstrap Script in Action

**On a fresh system without opkssh:**

![Bootstrap Menu - New System](images/opkssh-menu-new-system.png)

The bootstrap script automatically:
- Detects that opkssh is not installed
- Checks the latest available version
- Presents a clean menu with options to install or cancel

**On a system with existing opkssh installation:**

![Bootstrap Menu - Existing Installation](images/opkssh-menu-existing-install.png)

The smart bootstrap script:
- Detects the installed opkssh version
- Checks for available updates
- Finds existing configuration in `/etc/opk`
- Offers context-aware options:
  - Reconfigure existing installation
  - Report current status to tracker
  - Cancel

**Installation and Configuration Process:**

![Installation Progress](images/opkssh-install-status.png)

The bootstrap script handles the complete deployment process:
1. Downloads and installs opkssh
2. Configures OpenID provider settings
3. Sets up user authorization
4. Configures SSHD for opkssh authentication
5. Sets up SSH agent forwarding (with multi-shell support: bash, zsh, fish)
6. Reports deployment status to the tracker
7. All with detailed progress feedback and error handling

**Reporting to Tracker:**

![Report to Tracker](images/opkssh-report-tracker.png)

After installation or when using the "Report status" option, the script:
- Collects hostname, alias, IP, user, and configuration details
- Reports deployment status to the tracker server
- Confirms successful registration

### Deployment Management

#### Edit Deployments

![Edit Deployment](images/opkssh-gui-modify.png)

Click the "Edit" button on any deployment to modify:
- Hostname
- Alias (friendly name)
- IP Address
- SSH User
- Changes are saved immediately with visual feedback

#### Delete Deployments

Each deployment row has a "Delete" button that:
- Shows a confirmation dialog before deletion
- Immediately removes the deployment from the tracker
- Updates the dashboard statistics

#### Toggle SSH Agent Forwarding

The "SSH-Agent" column contains checkboxes that allow you to:
- Enable/disable SSH agent forwarding per host
- Changes are saved automatically via API
- Affects the generated SSH config (`ForwardAgent yes/no`)

### SSH Config Generator

The tracker can generate OpenSSH configuration for all successful deployments.

**Using IP Address Mode:**

![SSH Config - IP Mode](images/opkssh-gui-sshconfig.png)

Select "Use IP Address" to generate SSH config with:
- IP address in the `HostName` field
- Hostname shown as a comment
- Perfect for environments where DNS is unreliable

**Using Hostname Mode:**

![SSH Config - Hostname Mode](images/opkssh-gui-sshconfig-hostname.png)

Select "Use Hostname" to generate SSH config with:
- Hostname in the `HostName` field
- IP address shown as a comment
- Ideal when you have proper DNS resolution

Both modes include:
- User configuration
- Identity file path
- SSH agent forwarding setting (when enabled)
- Timestamp of generation
- Group filtering option (generate config for specific group or all)

Click "Download SSH Config" to download the configuration file, which can be:
- Copied directly into `~/.ssh/config`
- Used with the `update-ssh-config.sh` script for automatic integration

### API Documentation

![API Documentation](images/opkssh-gui-api.png)

The dashboard provides access to interactive API documentation at `/openapi.json`, showing all available endpoints:
- **POST /report** - Submit deployment reports
- **GET /reports** - Retrieve all deployment reports
- **DELETE /reports** - Clear all reports
- **GET /reports/{hostname}** - Get specific deployment
- **DELETE /reports/{hostname}** - Delete specific deployment
- **PATCH /reports/{hostname}** - Update deployment (e.g., SSH agent setting)
- **GET /ssh-config** - Generate SSH configuration
- **GET /health** - Health check endpoint
- **POST /api/bootstrap-token** - Create bootstrap deployment token
- **GET /bootstrap** - Download bootstrap installation script
- **GET /api/scripts/{script_name}** - Download deployment scripts
- **GET /api/latest-opkssh-version** - Get latest opkssh version from GitHub
- **GET /api/deployment-history/{hostname}** - View deployment timeline

Each endpoint shows authentication requirements (lock icon) and supports the OpenAPI/Swagger specification.

---

### Configuration Options

Edit `config.toml` to customize:

```toml
[server]
host = "0.0.0.0"  # Bind to all interfaces
port = 8080       # Default port

[auth]
mode = "basic"              # Auth mode: "none", "basic", or "oidc"
username = "admin"          # Basic auth username
password = "change-me"      # Basic auth password

[ssh_config]
default_use_hostname = true  # Use hostname (true) or IP (false) in SSH config
```

After changing configuration, restart the server:
```bash
docker-compose restart
```

---

## Client Scripts Usage

The client scripts are used on your local machine to deploy opkssh to remote hosts and manage SSH configurations.

All scripts can be found in the `scripts/` directory.

### Prerequisites

- Bash shell
- `curl` and `wget` installed
- `sudo` access (for deployment script)
- SSH or physical/direct access to target hosts

### 1. Deploy opkssh to a Remote Host

The `deploy-opkssh.sh` script installs and configures opkssh on a Debian-based Linux host.

#### Setup (First Time)

1. **Create your .env file:**
   ```bash
   cp .env.example .env
   ```

2. **Configure your environment:**
   ```bash
   nano .env  # or use your preferred editor
   ```

   Edit the following variables:
   ```bash
   # Tracker server URL
   TRACKER_URL="http://your-tracker-server:8080"

   # Tracker authentication
   TRACKER_USER="admin"
   TRACKER_PASS="your-password"

   # Default SSH principal
   DEFAULT_PRINCIPAL="root"

   # OpenID Provider Configuration
   PROVIDER_ISSUER="https://auth.yourdomain.com"
   PROVIDER_CLIENT_ID="your-client-id"
   PROVIDER_EXPIRY="24h"
   USER_EMAIL="your-email@yourdomain.com"
   ```

#### Usage

**Interactive deployment (prompts for username):**
```bash
ssh user@target-host
sudo ./deploy-opkssh.sh
```

**Non-interactive deployment (automated):**
```bash
ssh root@target-host
sudo ./deploy-opkssh.sh --user root --alias webserver-01
```

**With custom alias:**
```bash
sudo ./deploy-opkssh.sh --alias db-server-prod
```

**Options:**
- `--user USERNAME` - Local username/principal for SSH access (default: root)
- `--alias ALIAS` - Friendly alias for SSH config (default: hostname)
- `--tracker-url URL` - Override tracker URL from .env
- `--tracker-user USER` - Override tracker username from .env
- `--tracker-pass PASS` - Override tracker password from .env
- `--help` - Show help message

### 2. Report Existing Installation

The `report-opkssh.sh` script analyzes an existing opkssh installation and reports it to the tracker.

**Usage:**

```bash
./report-opkssh.sh
```

**With options:**
```bash
./report-opkssh.sh --alias production-db --status success
```

**Dry run (show what would be reported):**
```bash
./report-opkssh.sh --dry-run
```

**Options:**
- `--alias ALIAS` - Set a friendly alias
- `--status STATUS` - Override detected status (success/incomplete/failed)
- `--tracker-url URL` - Override tracker URL from .env
- `--tracker-user USER` - Override tracker username
- `--tracker-pass PASS` - Override tracker password
- `--dry-run` - Show report without sending
- `--help` - Show help message

### 3. Update Local SSH Config

The `update-ssh-config.sh` script fetches deployment data from the tracker and updates your `~/.ssh/config` file.

**Usage:**

**Basic usage:**
```bash
./update-ssh-config.sh
```

**With custom prefix:**
```bash
./update-ssh-config.sh --prefix "opk-"
```
This creates SSH hosts like: `opk-webserver-01`

**With custom identity file:**
```bash
./update-ssh-config.sh --identity-file ~/.ssh/my_opk_key
```

**Dry run (preview changes):**
```bash
./update-ssh-config.sh --dry-run
```

**Options:**
- `--prefix PREFIX` - Add prefix to host aliases (e.g., "opk-")
- `--identity-file FILE` - Path to SSH identity file (default: ~/.ssh/id_ecdsa)
- `--config FILE` - SSH config file to update (default: ~/.ssh/config)
- `--tracker-url URL` - Override tracker URL from .env
- `--tracker-user USER` - Override tracker username
- `--tracker-pass PASS` - Override tracker password
- `--no-backup` - Don't create backup of existing config
- `--dry-run` - Preview changes without applying
- `--help` - Show help message

**After updating, SSH to your hosts:**
```bash
ssh root@webserver-01
# or with prefix:
ssh root@opk-webserver-01
```

---

## Configuration

### Environment Variables (.env)

Copy `.env.example` to `.env` and configure:

```bash
# Tracker Server
TRACKER_URL="http://your-tracker-server:8080"
TRACKER_USER="admin"
TRACKER_PASS="your-password"

# Default Settings
DEFAULT_PRINCIPAL="root"

# OpenID Provider (required for deploy-opkssh.sh)
PROVIDER_ISSUER="https://auth.yourdomain.com"
PROVIDER_CLIENT_ID="your-client-id-here"
PROVIDER_EXPIRY="24h"
USER_EMAIL="your-email@yourdomain.com"
```

### Server Configuration (server/config.toml)

```toml
[server]
host = "0.0.0.0"
port = 8080

[auth]
mode = "basic"  # Auth mode: "none", "basic", or "oidc"
username = "admin"
password = "secure-password"

[ssh_config]
default_use_hostname = true
```

---

## OIDC Authentication Setup

The tracker supports three authentication modes:

### Mode: none
No authentication required. Use only for development.

### Mode: basic
HTTP Basic Auth with username/password (default). Session-based authentication enables proper logout functionality - users authenticate once and receive a session cookie.

**How Basic Auth Logout Works:**
- On login, credentials are verified and a session is created
- Session cookie (`opkssh_session`) is used for subsequent requests
- Logout invalidates the session and redirects to a "Logged Out" page
- Browser credential cache is cleared via realm change technique

### Mode: oidc
OpenID Connect with your SSO provider using PKCE (Proof Key for Code Exchange).

> **Note:** The tracker reuses the same OIDC provider you configured for opkssh deployments in the `[deployment.provider]` section. This means you only need to configure one SSO provider, and it will be used for both SSH authentication (via opkssh) and tracker dashboard access.

**How OIDC Works:**
1. User clicks "Login" and is redirected to SSO provider
2. Tracker uses OIDC Discovery to fetch endpoints from `{issuer}/.well-known/openid-configuration`
3. User authenticates with SSO provider (using PKCE for security)
4. SSO redirects back with authorization code
5. Tracker exchanges code for tokens using PKCE code verifier
6. User email is verified against `allowed_emails` list
7. Session is created with secure cookie

**OIDC Discovery:** Only the issuer URL from `[deployment.provider]` is needed - all other endpoints (authorization, token, logout) are automatically discovered from the provider's well-known configuration.

#### OIDC Configuration

1. **Configure config.toml:**

```toml
[auth]
mode = "oidc"

[auth.oidc]
# Redirect URI must match exactly what's registered with SSO provider
redirect_uri = "https://your-tracker-domain/auth/callback"

# Only these emails can access the dashboard
allowed_emails = [
    "admin@example.com",
    "user@example.com"
]

# Session persistence (required for Docker)
session_file = "/data/sessions.json"

# Cookie security - set to false only for local development without HTTPS
secure_cookies = true
```

2. **Configure your OIDC Provider:**

Add the tracker's URLs to your existing opkssh OIDC client application. Since the tracker reuses the same client configured in `[deployment.provider]`, you just need to add additional redirect URIs.

**Client ID:** Use the same client ID from `[deployment.provider].client_id`

**Add these Redirect URIs to your OIDC client:**

| URL Type | Production | Local Development |
|----------|------------|-------------------|
| **Callback URL** | `https://your-tracker-domain/auth/callback` | `http://localhost:8080/auth/callback` |
| **Post-Logout URL** | `https://your-tracker-domain/auth/logged-out` | `http://localhost:8080/auth/logged-out` |

> **Important:** The `redirect_uri` in your `config.toml` must exactly match what's registered in your OIDC provider (including protocol, domain, and path).

**Example OIDC Provider Configuration (Pocket ID / Keycloak / etc.):**

```
Client ID: your-opkssh-client-id
Client Type: Public (no secret)
PKCE: Enabled (S256)
Grant Type: Authorization Code

Redirect URIs:
  - https://your-tracker-domain/auth/callback
  - http://localhost:8080/auth/callback  (for development)

Post-Logout Redirect URIs:
  - https://your-tracker-domain/auth/logged-out
  - http://localhost:8080/auth/logged-out  (for development)

Scopes: openid, email, profile
```

3. **SSO Logout (RP-Initiated Logout)**

The tracker supports proper SSO logout using RP-Initiated Logout:
- When user clicks "Logout", they are redirected to SSO provider's `end_session_endpoint`
- SSO provider terminates the session
- User is redirected back to tracker's `/auth/logged-out` page
- This prevents auto-login after logout

**Required SSO Provider Settings:**
- Enable RP-Initiated Logout (most providers support this)
- Register post-logout redirect URI: `https://your-tracker-domain/auth/logged-out`

4. **Docker Network Requirements**

For OIDC authentication to work in Docker, the container must be able to reach your SSO provider:

```yaml
# If using a custom network without internet access (e.g., for reverse proxy)
# Add a second network with IP masquerade enabled:
services:
  opkssh-tracker:
    networks:
      - your-internal-network     # For reverse proxy
      - internet-access           # For OIDC provider access

networks:
  your-internal-network:
    external: true
  internet-access:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.enable_ip_masquerade: "true"
```

**Verify connectivity:**
```bash
docker exec -it opkssh-tracker python -c "import httpx; print(httpx.get('https://your-sso-provider/.well-known/openid-configuration').status_code)"
```

---

## Upgrading from Previous Versions

### Migration from v0.7.x to v0.8.x (Authentication Changes)

Version 0.8.0 introduces a new authentication configuration format. If you're upgrading from an older version, follow this guide.

#### Old Configuration Format (v0.6.x - v0.7.x)

```toml
[auth]
enabled = true        # REMOVED - no longer used
username = "admin"
password = "secret"
```

#### New Configuration Format (v0.8.x+)

```toml
[auth]
mode = "basic"        # NEW - replaces "enabled" (options: "none", "basic", "oidc")
username = "admin"
password = "secret"

# NEW - Required only for mode = "oidc"
[auth.oidc]
redirect_uri = "https://your-tracker-domain/auth/callback"
allowed_emails = ["admin@example.com"]
session_file = "/data/sessions.json"
secure_cookies = true
```

#### Migration Steps

1. **Open your `config.toml`**

2. **Replace the `[auth]` section:**

   | Old Setting | New Setting | Notes |
   |-------------|-------------|-------|
   | `enabled = true` | `mode = "basic"` | For HTTP Basic Auth |
   | `enabled = false` | `mode = "none"` | No authentication |
   | *(new)* | `mode = "oidc"` | For SSO login |

3. **For Basic Auth users** (most common):
   ```toml
   # Before (v0.7.x)
   [auth]
   enabled = true
   username = "admin"
   password = "your-password"

   # After (v0.8.x)
   [auth]
   mode = "basic"
   username = "admin"
   password = "your-password"
   ```

4. **For OIDC users** (new feature):
   ```toml
   [auth]
   mode = "oidc"

   [auth.oidc]
   redirect_uri = "https://your-tracker-domain/auth/callback"
   allowed_emails = ["your-email@example.com"]
   session_file = "/data/sessions.json"
   secure_cookies = true
   ```

5. **Restart the container:**
   ```bash
   docker-compose restart
   ```

#### Quick Reference: What Changed

| Change | Action Required |
|--------|-----------------|
| `enabled = true/false` removed | Replace with `mode = "basic"` or `mode = "none"` |
| New `mode` setting | Add `mode = "basic"`, `"oidc"`, or `"none"` |
| New `[auth.oidc]` section | Add only if using OIDC authentication |
| Logout now works properly | No action needed - automatic improvement |

#### Verify Migration

After updating, verify the server starts correctly:
```bash
docker-compose logs -f | head -50
```

Look for:
- `Auth mode: basic` or `Auth mode: oidc` - confirms new config is loaded
- No errors about missing configuration keys

---

## API Endpoints

The tracker server provides the following REST API endpoints:

### `POST /report`
Submit a deployment report.

**Requires authentication if enabled.**

**Request body:**
```json
{
  "hostname": "webserver-01",
  "alias": "web-prod",
  "ip": "192.168.1.100",
  "user": "root",
  "group": "production",
  "status": "success",
  "opkssh_version": "0.3.0",
  "os_info": "Debian 12",
  "error": ""
}
```

### `GET /reports`
Get all deployment reports.

**Requires authentication if enabled.**

**Query parameters:**
- `group` - Filter by group name (optional)

**Response:**
```json
[
  {
    "hostname": "webserver-01",
    "alias": "web-prod",
    "ip": "192.168.1.100",
    "user": "root",
    "group": "production",
    "status": "success",
    "opkssh_version": "0.3.0",
    "os_info": "Debian 12",
    "timestamp": "2025-01-15T10:30:00Z",
    "error": ""
  }
]
```

### `GET /reports/{hostname}`
Get a specific deployment report by hostname.

**Requires authentication if enabled.**

### `DELETE /reports/{hostname}`
Delete a deployment report.

**Requires authentication if enabled.**

### `GET /ssh-config`
Generate SSH config for all successful deployments.

**Requires authentication if enabled.**

**Query parameters:**
- `identity_file` - SSH identity file path (default: ~/.ssh/id_ecdsa)
- `prefix` - Prefix for host aliases (optional)
- `use_hostname` - Use hostname instead of IP (default: true)
- `group` - Filter by group name (optional)

**Response:** OpenSSH config format text

### `GET /api/groups`
List all groups with deployment counts and colors.

**Requires authentication if enabled.**

**Response:**
```json
[
  {
    "name": "production",
    "color": "#4CAF50",
    "description": "",
    "count": 5
  }
]
```

### `PUT /api/groups/{name}`
Rename a group or update its color/description.

**Requires authentication if enabled.**

**Request body:**
```json
{
  "new_name": "prod-servers",
  "color": "#2196F3",
  "description": "Production servers"
}
```

### `DELETE /api/groups/{name}`
Delete a group. Associated deployments become "Ungrouped".

**Requires authentication if enabled.**

### `GET /health`
Health check endpoint (no authentication required).

### `GET /`
Web dashboard showing all deployments with statistics.

### Authentication Endpoints

#### `GET /auth/login`
Initiates authentication flow.
- **Basic mode**: Shows login form or processes credentials
- **OIDC mode**: Redirects to SSO provider's authorization endpoint

#### `GET /auth/callback`
OIDC callback endpoint (OIDC mode only).
- Receives authorization code from SSO provider
- Exchanges code for tokens using PKCE
- Creates session and redirects to dashboard

#### `GET /auth/logout`
Terminates user session.
- **Basic mode**: Invalidates session, shows logged-out page
- **OIDC mode**: Redirects to SSO provider's `end_session_endpoint` for full logout

#### `GET /auth/logged-out`
Post-logout landing page. Displayed after successful logout from SSO provider.

---

## Troubleshooting

### Server Issues

**Container won't start:**
```bash
# Check logs
docker-compose logs

# Check if port is already in use
netstat -tulpn | grep 8080

# Check config file syntax
cat config.toml
```

**Can't access web dashboard:**
- Verify the server is running: `docker-compose ps`
- Check firewall rules: `sudo ufw status`
- Verify port binding: `netstat -tulpn | grep 8080`

**Authentication failures:**
- Verify credentials in `server/config.toml`
- Verify credentials in `.env` match server config

### Client Script Issues

**"Missing required configuration variables":**
- Ensure `.env` file exists
- Verify all required variables are set in `.env`
- Check variable names match exactly (case-sensitive)

**"opkssh is not installed":**
- The deployment script installs opkssh automatically
- For report script, opkssh must already be installed
- Verify with: `which opkssh`

**SSH config not updating:**
- Check tracker URL is accessible: `curl http://tracker:8080/health`
- Verify authentication credentials
- Try with `--dry-run` first to preview changes
- Check `~/.ssh/config` permissions: `ls -la ~/.ssh/config`

**"Authentication failed":**
- Verify `TRACKER_USER` and `TRACKER_PASS` in `.env`
- Verify they match `server/config.toml`
- Check auth mode in config: `[auth] mode = "basic"` or `"oidc"`

### OIDC Issues

**"Connect timeout" or "Connection refused" during login:**
- Container cannot reach SSO provider
- Check Docker network configuration (see [Docker Network Requirements](#docker-network-requirements))
- Verify DNS resolution: `docker exec opkssh-tracker nslookup your-sso-provider`
- Test connectivity: `docker exec opkssh-tracker curl -I https://your-sso-provider`

**"Access denied for email@example.com":**
- Email not in `allowed_emails` list in config.toml
- Add the email to the list and restart the container

**"Invalid state parameter" or "Invalid code verifier":**
- PKCE verification failed - usually means cookies expired
- Clear browser cookies and try again
- Check that `redirect_uri` matches exactly (including trailing slashes)

**Logout redirects back to logged-in state:**
- SSO provider session still active
- Ensure RP-Initiated Logout is configured (see [SSO Logout](#sso-logout-rp-initiated-logout))
- Register post-logout redirect URI with your SSO provider

**"No matching key found in JWKS":**
- Token signing key not found in provider's JWKS
- Clear the OIDC cache by restarting the container
- Check if your SSO provider rotated keys recently

### Network Issues

**Can't reach tracker from clients:**
```bash
# Test connectivity
curl http://your-tracker-server:8080/health

# With authentication
curl -u admin:password http://your-tracker-server:8080/health

# Check DNS resolution
nslookup your-tracker-server

# Check network route
traceroute your-tracker-server
```

---

## Security Considerations

1. **Change default passwords** - Always change the default password in `server/config.toml`
2. **Use HTTPS** - Consider putting the tracker behind a reverse proxy with SSL/TLS
3. **Firewall rules** - Restrict access to port 8080 to known client IPs
4. **Keep .env private** - Never commit `.env` to version control
5. **Regular updates** - Update the Docker image regularly: `docker-compose pull && docker-compose up -d`

---

## Support

For issues, questions, or contributions, open an issue in this repo.

---

## License

See LICENSE file for details.
