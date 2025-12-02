# Changelog

## [0.4.0] - 2024-12-02

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
