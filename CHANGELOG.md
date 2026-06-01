# Changelog

## [0.9.0] - 2026-06-01

### Added
- **Clickable column sorting on the dashboard** — sort the deployment table by hostname
  or by group by clicking the column header. The selected column and direction persist
  across page reloads, and "Ungrouped" always sorts last.

### Changed

#### Dashboard and Auth Page Redesign
Full visual refresh of the web UI, working with the existing vanilla-CSS stack — no
framework added, no functionality changed.

- **Shared stylesheet**:
  - All five pages (dashboard, login, access-denied, logout, logged-out) now link a
    single stylesheet served from `GET /static/app.css` instead of each embedding its
    own `<style>` block — removes the duplicated CSS that had drifted between pages
  - Design tokens (CSS custom properties) for colours, surfaces, shadows, and radii
  - One indigo accent colour; green and red are reserved for success/failure only
  - `Outfit` display font with a system fallback; tabular figures for the data table,
    stat counters, and timestamps
  - Branded SVG favicon served from `GET /static/favicon.svg`

- **Responsive and accessibility fixes**:
  - Added `charset` and `viewport` meta tags to every page — the dashboard is now
    usable on mobile (previously rendered at desktop width with no viewport tag)
  - Deployment table wrapped for horizontal scrolling on small screens
  - Visible keyboard focus rings and pressed-state feedback on interactive elements
  - Centred auth pages use `100dvh` to avoid the mobile-browser viewport jump

- **Interaction polish**:
  - Replaced all native `alert()`/`confirm()`/`prompt()` calls with non-blocking
    toasts and styled in-page dialogs
  - Deployment status shown as a coloured pill badge instead of plain red/green text
  - Timestamps rendered in a readable format with the raw value in the tooltip
  - Composed empty state with a call to action when no deployments exist
  - Single-row group reassignment updates the badge in place instead of reloading

### Fixed

#### Bootstrap and report persistence
- Re-reporting a host no longer clears its alias or group. An empty alias or group in an
  incoming report now keeps the previously stored value — clearing is done from the
  dashboard, not by sending an empty report.
- Bootstrap tokens now carry the preset group and non-interactive overrides through to the
  generated script; previously these were silently dropped.
- The bootstrap script fetches the host's existing alias and group from the tracker before
  reporting, and preserves the group when re-run on an already-tracked host.
- The interactive "Hostname alias" prompt now defaults to the alias already recorded on the
  tracker (falling back to the hostname), so re-running bootstrap no longer resets a
  customized alias.

#### UI
- Login page CSS no longer renders broken: the page previously emitted literal `{{`/`}}`
  braces because the template was returned without being formatted; moving styles to the
  external stylesheet resolves it.

## [0.8.0] - 2026-01-13

### Added

#### OIDC Authentication with SSO Login
Full OpenID Connect authentication support using PKCE (Proof Key for Code Exchange).

- **OIDC Authentication Flow**:
  - Reuses the same SSO provider configured for opkssh deployments (`[deployment.provider]`)
  - Automatic OIDC Discovery via `{issuer}/.well-known/openid-configuration`
  - PKCE-based authorization code flow (S256 challenge method)
  - Email-based access control via `allowed_emails` configuration
  - Secure session management with encrypted cookies
  - Support for any OIDC-compliant provider (Pocket ID, Keycloak, Auth0, etc.)

- **SSO Logout (RP-Initiated Logout)**:
  - Proper logout flow that terminates both local and SSO sessions
  - Redirects to SSO provider's `end_session_endpoint` with `id_token_hint`
  - Post-logout redirect back to tracker's `/auth/logged-out` page
  - Prevents auto-login after logout

- **Session-Based Basic Auth**:
  - Basic Auth mode now uses session cookies for proper logout support
  - Login creates a session instead of relying on browser credential cache
  - Logout invalidates session and shows "Logged Out" page
  - Browser credential cache cleared via realm change technique

- **New Authentication Modules**:
  - `auth.py`: OIDC authentication handler with PKCE, token validation, session management
  - `session_store.py`: Thread-safe session store with file-based persistence and automatic expiry cleanup

- **New API Endpoints**:
  - `GET /auth/login` - Initiates authentication (Basic form or OIDC redirect)
  - `GET /auth/callback` - OIDC callback for authorization code exchange
  - `GET /auth/logout` - Terminates session (local or SSO logout)
  - `GET /auth/logged-out` - Post-logout landing page
  - `GET /auth/clear-credentials` - Clears browser credential cache (Basic mode)

- **Configuration Options** (`[auth.oidc]` section):
  - `redirect_uri` - OIDC callback URL (must match SSO provider registration)
  - `allowed_emails` - Email allowlist for access control
  - `session_file` - Path to session persistence file (default: `/data/sessions.json`)
  - `secure_cookies` - Enable secure cookie flag (set `false` for local dev without HTTPS)

- **Docker Updates**:
  - Dockerfile now includes `auth.py` and `session_store.py` modules
  - Dependencies updated: `httpx`, `authlib`, `PyJWT`, `itsdangerous`
  - Multi-network example for containers needing internet access for OIDC

- **OIDC Provider Configuration Requirements**:
  - Add Callback URL to your OIDC client: `https://your-tracker-domain/auth/callback`
  - Add Post-Logout URL to your OIDC client: `https://your-tracker-domain/auth/logged-out`
  - Same client ID as configured in `[deployment.provider]` section

- **Documentation**:
  - Comprehensive OIDC setup guide in README.md
  - Migration guide for upgrading from v0.7.x (`enabled = true/false` → `mode = "basic/oidc/none"`)
  - Docker network configuration for OIDC connectivity
  - OIDC troubleshooting section
  - Authentication endpoints documentation

### Breaking Changes
- **Configuration format changed**: `[auth] enabled = true/false` replaced with `[auth] mode = "basic/oidc/none"`
  - `enabled = true` → `mode = "basic"`
  - `enabled = false` → `mode = "none"`
  - See [Migration Guide](README.md#upgrading-from-previous-versions) in README.md

### Changed
- Version bumped to 0.8.0
- Dashboard logout button now works for both Basic and OIDC modes
- Authentication verification refactored to support session cookies
- OIDC initialization happens on server startup with session cleanup

### Fixed
- Logout now properly terminates SSO sessions (previously only cleared local session)
- Basic Auth logout no longer allows auto-login via cached browser credentials
- Private browsing windows no longer auto-authenticate

### Technical Details
- `OIDCAuth` class handles complete OIDC flow with PKCE
- `SessionStore` provides thread-safe session management with file persistence
- JWKS caching prevents repeated key fetches during token validation
- Automatic cleanup of expired sessions on load and via periodic task
- State and code verifier stored in signed cookies for CSRF/replay protection

## [0.7.0] - 2025-12-25

### Added

#### Deployment Grouping Feature
Organize deployments into logical groups with visual distinction and filtering capabilities.

- **Group Assignment**:
  - Single group per deployment (optional, defaults to "Ungrouped")
  - Implicit group creation: typing a new group name auto-creates it
  - Group field added to deployment reports and bootstrap tokens
  - Existing deployments gracefully handled as "Ungrouped"

- **Group Management Modal**:
  - Access via "Manage Groups" button in dashboard header
  - View all groups with deployment counts
  - Rename groups (updates all associated deployments)
  - Delete groups (moves deployments to "Ungrouped")
  - Color picker for visual customization
  - Real-time updates without page reload

- **Group Color System**:
  - 8-color default palette for auto-created groups
  - Custom color picker in group management
  - Colors displayed as badges in dashboard table
  - Consistent coloring across all UI components

- **Dashboard Filtering**:
  - Group selector dropdown in dashboard header
  - Filter deployments by group or view all
  - Statistics cards update to show filtered counts
  - Smooth transitions when switching groups

- **Inline Group Editing**:
  - Click group badge in table to edit
  - Dropdown with existing groups + "Create new group" option
  - Type custom name to create new group on-the-fly
  - Cancel/save controls with keyboard support (Escape/Enter)

- **SSH Config Integration**:
  - Group filter in SSH config download modal
  - Generate config for specific group or all deployments
  - Group comments in generated SSH config files
  - API support: `GET /ssh-config?group=production`

- **Bootstrap Token Groups**:
  - Group field in bootstrap modal with autocomplete
  - Pre-populate dropdown from existing groups
  - Allow creating new group by typing name
  - Selected group embedded in generated token
  - Deployed hosts auto-assigned to specified group

- **New API Endpoints**:
  - `GET /api/groups` - List all groups with deployment counts and colors
  - `PUT /api/groups/{name}` - Rename group or update color/description
  - `DELETE /api/groups/{name}` - Delete group (deployments become Ungrouped)
  - `GET /reports?group={name}` - Filter deployments by group

- **Data Storage**:
  - New `groups.json` file for group metadata (color, description)
  - `GroupStore` class for group management operations
  - Automatic color assignment from palette for new groups
  - Migration-safe: works with existing deployments

### Changed
- Version bumped to 0.7.0
- Dashboard table includes new "Group" column with colored badges
- Statistics cards now group-aware (show filtered vs total counts)
- Bootstrap token payload extended with optional `group` field

### Technical Details
- `GroupStore` class manages group persistence and operations
- Hybrid approach: groups created implicitly, managed explicitly
- Color palette cycles through 8 distinct colors for auto-creation
- All group operations maintain referential integrity with deployments

## [0.6.4] - 2025-12-05

### Added
- **Automatic SSH Agent Configuration**: Deployment scripts now automatically configure SSH agent for target users
  - **Multi-Shell Support**: Detects user's default shell and configures appropriately
    - Bash: Updates `~/.bashrc` with POSIX-compatible syntax
    - Zsh: Updates `~/.zshrc` with POSIX-compatible syntax
    - Fish: Updates `~/.config/fish/config.fish` with Fish-specific syntax
    - Unknown shells: Falls back to bash configuration in `~/.bashrc`
  - **Smart Configuration**:
    - Only starts ssh-agent if `SSH_AUTH_SOCK` is not already set (prevents nested agents)
    - Uses marker comments for duplicate detection: `# opkssh: SSH agent configuration (auto-generated)`
    - Automatically runs `ssh-add` to load default SSH keys
    - Suppresses errors with `2>/dev/null` if no keys exist
  - **Shell-Specific Syntax**:
    - Bash/Zsh: `if [ -z "$SSH_AUTH_SOCK" ]; then eval "$(ssh-agent -s)"; ssh-add 2>/dev/null; fi`
    - Fish: `if not set -q SSH_AUTH_SOCK; eval (ssh-agent -c); ssh-add 2>/dev/null; end`
  - **Implementation**:
    - New `configure_ssh_agent()` function added to both `server/main.py` (bootstrap script generator) and `deploy-opkssh.sh`
    - Automatically called after `configure_opkssh()` completes
    - Detects shell via `getent passwd` and configures appropriate RC file
    - Creates directories if needed (e.g., `~/.config/fish/`)
    - Properly handles file ownership with `chown`
  - **Benefits**:
    - Users no longer need to manually configure ssh-agent
    - Prevents SSH agent forwarding issues on Debian-based systems
    - Idempotent: running multiple times won't create duplicates
    - Works seamlessly across different shell environments

### Fixed
- **Bootstrap Deployment**: Fixed incorrect SSHD configuration generated by bootstrap script
  - Previously created `/etc/ssh/sshd_config.d/60-opk-ssh.conf` with wrong content:
    - Missing required arguments: `verify %u %k %t`
    - Wrong user: `nobody` instead of `opksshuser`
  - Now relies on the opkssh installer to create the correct SSHD configuration
  - Bootstrap script no longer overwrites the installer's correct configuration
  - This fix ensures SSH authentication via opkssh works correctly on bootstrap-deployed hosts

## [0.6.3] - 2025-12-05

- Fixing bugs in Bootstrap deployment

## [0.6.2] - 2025-12-04

- Fixing bugs in Bootstrap deployment

## [0.6.1] - 2025-12-04

- Fixing bugs in Bootstrap deployment

## [0.6.0] - 2025-12-03

### Added

#### Bootstrap Deployment Feature
- **One-Command Deployment**: Generate a single `curl | bash` command from the web dashboard to deploy opkssh to any server
  - No manual script distribution required
  - No `.env` file configuration needed on target hosts
  - Token-based authentication with 1-hour expiry (configurable)
  - Tokens can be reused on multiple servers within expiry window

- **Smart Installation Script**:
  - 524-line self-contained bash script generated on-demand
  - Auto-detects existing opkssh installations and versions
  - Checks for available updates from GitHub
  - Interactive menu with context-aware options:
    - Install opkssh (if not installed)
    - Update to latest version (if update available)
    - Reconfigure existing installation
    - Report current status to tracker
  - Beautiful box-drawing UI with color-coded output
  - Comprehensive error handling with automatic failure reporting

- **Non-Interactive Mode**:
  - Pre-configure deployment values in the web UI
  - Fully automated deployment with no prompts
  - Perfect for CI/CD pipelines and mass deployments
  - Values embedded securely in bootstrap token

- **Web Dashboard Enhancements**:
  - New "🚀 Generate Bootstrap Command" button in header
  - Bootstrap modal with:
    - Token generation form
    - Non-interactive mode toggle with pre-configuration fields
    - Real-time token expiry countdown (MM:SS format)
    - One-click copy-to-clipboard functionality
    - Token regeneration option
  - Deployment History modal:
    - Click any hostname to view deployment timeline
    - Event cards showing: timestamp, action, version, status, duration, errors
    - Visual status indicators (✅/❌)
    - Sorted by newest first

- **Backend Infrastructure**:
  - **Encryption Key Management**: Auto-generates Fernet key on first run, saves to `/data/encryption.key`
  - **BootstrapTokenStore**: Manages tokens with expiry, usage logging, and automatic cleanup
  - **DeploymentHistoryStore**: Tracks all deployment events per hostname
  - **GitHubVersionCache**: Server-side caching of latest opkssh version (hourly refresh)
    - Prevents GitHub API rate limiting (60 req/hour without token)
    - Optional GitHub API token support for higher limits (5000 req/hour)
  - **Background Tasks**:
    - Periodic GitHub version refresh (hourly)
    - Automatic cleanup of expired tokens (hourly)

- **New API Endpoints**:
  - `POST /api/bootstrap-token` - Generate deployment token
  - `GET /bootstrap?token=<ID>` - Serve bootstrap installation script
  - `GET /api/scripts/{script_name}?token=<ID>` - Download deployment scripts
  - `GET /api/latest-opkssh-version` - Get cached opkssh version from GitHub
  - `GET /api/deployment-history/{hostname}` - Get deployment timeline

- **Configuration Extensions**:
  - New `[deployment]` section: default principal, user email, provider settings
  - New `[bootstrap]` section: token expiry, rate limits, encryption key
  - New `[github]` section: repository, cache duration, API token
  - All settings documented in `config.toml.example`

- **Docker Integration**:
  - Deployment scripts copied to `/scripts/` directory in container
  - Git commit hash extraction for version tracking
  - Build script (`server/build.sh`) for automated builds with version tracking
  - Updated dependencies: cryptography, httpx
  - Environment variable support: `BOOTSTRAP_ENCRYPTION_KEY`, `GITHUB_API_TOKEN`

- **Security Features**:
  - Fernet encryption for tracker credentials in tokens
  - Token expiry with configurable duration (default: 1 hour)
  - Usage logging and audit trail
  - Script name whitelist for security
  - Optional HTTPS enforcement

- **Web UI/UX Improvements**:
  - 450+ lines of CSS for professional styling
  - Modal system with smooth animations (fade-in, slide-down)
  - Modern form components with focus states
  - Responsive flexbox layouts
  - Timeline/event styling for deployment history
  - Clickable hostnames (blue underlined) to view history
  - Error handling with user-friendly messages

- **Documentation**:
  - Comprehensive README.md update with bootstrap deployment section
  - Detailed CLAUDE.md update with implementation details
  - API endpoint documentation with examples
  - Configuration examples and security notes

#### Server Deletion Feature
- **Web Dashboard**:
  - New "Delete" button in each deployment row
  - Confirmation dialog before deletion
  - Immediate removal from table on success
  - Error handling with user feedback

### Changed
- Version bumped to 0.6.0
- Docker image now includes deployment scripts in `/scripts/`
- Server startup initializes GitHub version cache immediately
- Backend uses modern async/await patterns for API calls
- Frontend uses modern JavaScript (fetch API, clipboard API)

### Technical Details
- Main application file (`main.py`) expanded to 2600+ lines
- Bootstrap script generator creates fully self-contained bash scripts
- Automatic data migration for new storage files
- Backward compatible with traditional deployment scripts
- `.env` files still supported for manual deployments

## [0.4.0] - 2025-12-02

### Added

#### SSH Agent Forwarding Support
- **Server Configuration**: New `default_ssh_agent` parameter in `config.toml` under `[ssh_config]` section
  - Controls default SSH agent forwarding setting for new deployments
  - Defaults to `true` (enabled)
  - Existing deployments are automatically migrated based on this setting on first load

- **Web Dashboard**:
  - New "SSH-Agent" column with interactive checkboxes
  - Toggle SSH agent forwarding per-host directly from the dashboard
  - Changes saved immediately via PATCH API endpoint

- **Deployment Scripts**:
  - `deploy-opkssh.sh`: Added `--ssh-agent` and `--no-ssh-agent` flags
  - `report-opkssh.sh`: Added `--ssh-agent` and `--no-ssh-agent` flags
  - Environment variable `SSH_AGENT` can be set in `.env` file (default: `true`)

- **SSH Config Generation**:
  - Automatically adds `ForwardAgent yes` directive when `ssh_agent` is enabled
  - Configurable per-deployment via dashboard or command-line flags

- **API Changes**:
  - `/report` endpoint: Accepts optional `ssh_agent` boolean field
  - `/reports/{hostname}` PATCH endpoint: Supports updating `ssh_agent` field
  - Deployment data model extended with `ssh_agent` field

#### Hostname/IP Mode Control
- **update-ssh-config.sh**: New command-line flags for controlling HostName field format
  - `--use-hostname`: Use hostname in HostName field (IP shown as comment)
  - `--use-ip`: Use IP address in HostName field (hostname shown as comment)
  - Overrides server's default setting from `config.toml`

### Changed
- Data schema: All deployment records now include `ssh_agent` field
- Migration logic ensures backward compatibility with existing deployments

### Technical Details
- Automatic migration runs on data load for existing deployments
- PATCH endpoint at `/reports/{hostname}` supports partial updates
- Server config default applied to new deployments if `ssh_agent` not specified
