# Changelog

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
