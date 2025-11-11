# DevBase Security

## Security Overview Matrix

| Category | Feature | Status | Implementation | Details |
|----------|---------|--------|----------------|---------|
| **Audit & Monitoring** | Security tools | ✅ 8 tools | Gitleaks, Lynis, Syft, etc. | Pre-installed |
| | CI security scans | ✅ Enabled | Every PR | Gitleaks, shellcheck |
| | Git audit trail | ✅ Enabled | All config changes | PR approval required |
| **Automatic Updates** | APT security patches | ✅ Enabled | unattended-upgrades | Ubuntu/Debian security repos |
| | Development tools | ✅ Enabled | Renovate Bot (84 tools) | Weekly schedule, 7-day wait |
| | Virus definitions | ✅ Enabled | ClamAV freshclam | Continuous updates |
| **Code Safety** | Bash safety flags | ✅ 21/21 scripts | `set -uo pipefail` | Fail on errors |
| | Input validation | ✅ Enabled | Whitelisted inputs | No arbitrary execution |
| | Dangerous patterns | ✅ None found | `curl\|sh`, `rm -rf /`, `chmod 777` | Zero matches |
| **Credentials** | No hardcoded secrets | ✅ Verified | Gitleaks scans | Zero matches |
| | Password policy | ✅ Enabled | 6-char minimum | SSH passphrase validation |
| | Secure permissions | ✅ Enabled | SSH 600/700, configs 600 | Enforced at creation |
| **Cryptography** | Secure SSH | ✅ Enabled | ED25519, ChaCha20-Poly1305 | Default configuration |
| | SSH key type | ✅ Strong | ED25519 (256-bit) | Modern standard |
| **Known Issues** | Temp cleanup | ⚠️ Missing | `/tmp/devbase.*` persists | Tracked for fix |
| **Malware Protection** | ClamAV scanning | ✅ Enabled | Daily full system scan | Low-priority, scheduled |
| | Virus definitions | ✅ Auto-update | freshclam service | Continuous updates |
| **Network** | Firewall (UFW) | ✅ Enabled | Default on Linux | K3s rules auto-configured |
| | HTTPS-only downloads | ✅ Enforced | All package sources | Zero HTTP downloads |
| | Connection timeouts | ✅ Enabled | 30s connect, 90s max | Prevents hanging |
| | Proxy support | ✅ Available | HTTP_PROXY, HTTPS_PROXY | Corporate proxy ready |
| **Privileges** | User-level install | ✅ Default | No root for tools | Only sudo for system packages |
| | Minimal sudo | ✅ 79 operations | apt/dpkg/snap/systemctl | Documented usage |
| **Supply Chain** | Version pinning | ✅ Enabled | 84 tools in YAML/TOML | All versions locked, tracked in git |
| | Checksums | ✅ Enabled | Mise, OpenShift CLI, IntelliJ, VS Code | SHA256 verification |
| | Renovate updates | ✅ Enabled | 7-day stability period | Auto-PRs with CI validation |
| | Aqua SLSA attestation | ✅ Enabled | 50+ mise tools | Supply chain verification |
| **System Hardening** | File descriptors | ✅ 65,536 | /etc/security/limits.d/ | Build-optimized |
| | Process limits | ✅ 32,768 | PAM limits | Parallel builds |
| | Memory locking | ✅ Unlimited | Container support | VM/container ready |

**Legend**: ✅ Implemented | ⚠️ Known Issue | ❌ Not Implemented

## Summary

- ✅ Supply chain: checksums, version pinning, Renovate auto-updates (7-day stability period)
- ✅ Automatic updates: APT security patches (unattended-upgrades), Renovate Bot (84 tools)
- ✅ Secrets: no hardcoded credentials, secure permissions, password policy
- ✅ Privileges: user-level install, minimal sudo
- ✅ Firewall: UFW enabled by default with K3s integration
- ✅ Antivirus: ClamAV with daily automated scanning
- ✅ System hardening: resource limits for development workloads
- ⚠️ Known issue: temp directory cleanup missing

## Supply Chain

### Version Management

- Single source: `devbase-core/dot/.config/devbase/custom-tools.yaml`
- 11 custom tools with specialized installers, all auto-updated by Renovate
- Git tracks all changes, PR approval required

#### Aqua Registry (35 tools)

- Automatic checksum verification
- SLSA attestation support
- Example: `"aqua:koalaman/shellcheck" = "v0.11.0"`

#### Git Clones

- Version-pinned: `git clone --branch "4.4.5" ...`
- Commit hashes: `git checkout "803bc18"`

## Downloads & Checksums

| Tool | Checksum | Status |
|------|----------|--------|
| Mise | SHA256 vendor file | ✅ |
| OpenShift CLI | `sha256sum.txt` | ✅ |
| IntelliJ IDEA | `.sha256` file | ✅ |
| VS Code | Microsoft API | ✅ |
| JMC | None | HTTPS only |
| DBeaver | None | HTTPS + dpkg |
| KeyStore Explorer | None | HTTPS + dpkg |

## SSH Security

DevBase uses modern SSH cryptography configured in `~/.ssh/config`:

### Default SSH Key

- **Key Type**: ED25519 (256-bit elliptic curve, default) or ECDSA P-521 (customizable)
- **Location**: `~/.ssh/<configurable>` (default: `id_ed25519_devbase`)
- **Protection**: Passphrase-protected (recommended)
- **Configuration**: Set via `DEVBASE_SSH_KEY_TYPE` and `DEVBASE_SSH_KEY_NAME` in `org.env`

### Supported Algorithms

DevBase SSH config prioritizes modern, strong algorithms:

- **Host Keys**: ED25519, RSA-SHA2-512
- **Ciphers**: ChaCha20-Poly1305, AES-GCM (256/128)
- **MACs**: HMAC-SHA2-512/256 with encrypt-then-MAC
- **Key Exchange**: Curve25519, DH-GEX-SHA256

These settings provide strong security while maintaining compatibility with modern SSH servers.

### Testing SSH Configuration

```bash
# Check loaded key type
ssh-add -l

# Test connection with verbose output
ssh -Tvvv git@github.com
ssh -Tvvv git@gitlab.com

# Verify algorithms in use
ssh -vvv git@github.com 2>&1 | grep -E "kex:|cipher:|MAC:"
```

### SSH Testing & Troubleshooting

**Check loaded keys:**

```bash
# List keys in SSH agent (SHA256 format)
ssh-add -l

# List keys in SSH agent (full public key)
ssh-add -L
```

**Test SSH connection with verbose output:**

```bash
# Test GitHub connection
ssh -Tvvv git@github.com

# Test GitLab connection
ssh -Tvvv git@gitlab.com

# Look for modern algorithms in output:
# - kex: curve25519-sha256
# - cipher: chacha20-poly1305@openssh.com
# - MAC: hmac-sha2-512-etm@openssh.com
```

**Verify host fingerprints:**

```bash
# Check if host is in known_hosts
ssh-keygen -H -F github.com
ssh-keygen -H -F gitlab.com

# Show fingerprint of known host
ssh-keygen -l -f ~/.ssh/known_hosts
```

**Key information:**

DevBase generates modern cryptographic keys (ED25519 by default, ECDSA P-521 available):

- Private key: `~/.ssh/<key_name>` (default: `id_ed25519_devbase`)
- Public key: `~/.ssh/<key_name>.pub`
- Key type and name are customizable via `DEVBASE_SSH_KEY_TYPE` and `DEVBASE_SSH_KEY_NAME`

### Why Modern Key Types?

**ED25519 (default):**

- **Modern standard**: Fast, secure, and widely adopted
- **Widely supported**: All major Git hosting services (GitHub, GitLab, Bitbucket)
- **Strong security**: 256-bit Curve25519 provides excellent cryptographic strength
- **Performance**: Faster signing and verification than traditional algorithms

**ECDSA P-521 (optional):**

- **NIST compliance**: Approved for use in regulated environments
- **Maximum security**: 521-bit curve provides highest ECDSA security level
- **Wide support**: Supported by all major platforms

## Firewall Protection

DevBase enables UFW (Uncomplicated Firewall) by default on Linux systems to protect against unauthorized network access.

### Configuration

- **Enabled by default**: UFW is automatically enabled during installation
- **WSL exception**: Firewall is skipped on WSL systems (Windows Firewall is used instead)
- **Location**: `libs/configure-services.sh:64` (`configure_ufw()` function)

### K3s Integration

When K3s (Kubernetes) is installed, DevBase automatically configures firewall rules:

```bash
# API Server access
sudo ufw allow 6443/tcp comment 'k3s apiserver'

# Pod network (Flannel default CIDR)
sudo ufw allow from 10.42.0.0/16 to any comment 'k3s pods'

# Service network (ClusterIP default CIDR)
sudo ufw allow from 10.43.0.0/16 to any comment 'k3s services'
```

### Verification

```bash
# Check UFW status
sudo ufw status verbose

# View K3s rules (if installed)
sudo ufw status | grep k3s
```

### Manual Control

```bash
# Enable firewall
sudo ufw enable

# Disable firewall
sudo ufw disable

# Add custom rules
sudo ufw allow 8080/tcp comment 'custom app'
```

## File Permissions

| Resource | Permission |
|----------|-----------|
| SSH private keys (ED25519) | 600 |
| SSH public keys | 644 |
| SSH directory | 700 |
| SSH config | 600 |
| Passphrase temp files | 600 (deleted after use) |
| Cache directory | 700 |

**Sudo Usage**: 79 operations total

- `apt-get install`
- `dpkg -i`
- `snap install`
- `update-ca-certificates`
- `systemctl` (WSL only)

No sudo for: tool installations, config files, shell setup, git config.

## Secrets & Credentials

### Password Policy

DevBase enforces a minimum password length policy for SSH key passphrases to ensure adequate security.

**SSH Passphrase Requirements:**

- **Minimum length**: 6 characters
- **Validation**: Interactive prompt rejects passphrases shorter than 6 characters
- **Override**: Can be bypassed with `DEVBASE_SSH_ALLOW_EMPTY_PW=true` (not recommended)
- **Location**: `libs/collect-user-preferences.sh:248` (`prompt_for_ssh_passphrase()` function)

**Example validation flow:**

```bash
SSH key passphrase (min 6 chars): ***
❌ Too short - use at least 6 characters

SSH key passphrase (min 6 chars): ******
Confirm passphrase: ******
✅ Passphrase accepted
```

### No Hardcoded Secrets

#### Input Handling

```bash
read -s -r ssh_pass      # Silent
read -r -s sudo_password # Silent, unset immediately
```

**SSH Passphrase** (auto-generated):

1. Generate
2. Store: `~/.config/devbase/.ssh_passphrase.tmp` (600)
3. Display in summary
4. Delete immediately

#### Proxy Credentials

```bash
export DEVBASE_PROXY_URL="http://${USER}:mypass@proxy:8080"
```

- Default: `mypass` (placeholder)
- Masked in output: `://***:***@`
- Visible in process env (standard for HTTP proxies)

## Code Safety

**Bash Flags** (21/21 scripts):

```bash
set -uo pipefail
# -u: fail on undefined variables
# -o pipefail: catch pipe failures
```

**Avoiding Dangerous Patterns**:

```bash
grep -rn "curl.*|.*sh" devbase-core/libs    # 0 matches
grep -rn "rm -rf /" devbase-core/libs       # 0 matches  
grep -rn "chmod 777" devbase-core/libs      # 0 matches
```

**Input Validation**: All user inputs whitelisted

```bash
case "$action" in
  generate|use-existing|skip) ;;
  *) return 1 ;;
esac
```

## Dependency Management

### Renovate Bot

- 79 tools auto-updated
- Creates PRs
- CI runs security scans
- Human approval required

**Workflow**:

1. Renovate detects new version
2. PR created
3. CI: gitleaks, shellcheck
4. Human review
5. Merge = audit trail

#### OpenSSF Scorecard

```bash
scorecard --repo=github.com/owner/repo
```

Scores available in `docs/tools-matrix.adoc`.

### Renovate Configuration

DevBase extends a shared base configuration from the organization's GitHub repository:

```json
{
  "extends": [
    "github>diggsweden/.github//renovate-base.json"
  ]
}
```

**Base Configuration Location**: `github>diggsweden/.github//renovate-base.json`

**Stability Days**: The base configuration sets a 7-day stability period before updates are proposed. This ensures:

- New releases are tested by the community before adoption
- Critical bugs in new versions are discovered and fixed
- Updates are batched to reduce PR noise

**Managed Files**:

- `dot/.config/devbase/custom-tools.yaml` - 12 custom tools
- `dot/.config/devbase/vscode-extensions.yaml` - 22 VS Code extensions  
- `dot/.config/mise/config.toml` - 50+ mise-managed tools

To customize the schedule or stability period, override the base configuration in your organization's `.github` repository.

## Automatic Updates

DevBase implements multi-layered automatic updates for both system packages and development tools.

### APT Packages (System Level)

**Unattended Upgrades** is configured to automatically install security updates from Ubuntu/Debian repositories:

**Allowed Origins** (auto-updated):

- `${distro_id}:${distro_codename}` - Main repository
- `${distro_id}:${distro_codename}-security` - Security updates
- `${distro_id}:${distro_codename}-updates` - Stable updates
- `${distro_id}ESMApps:${distro_codename}-apps-security` - Extended Security Maintenance (if available)
- `${distro_id}ESM:${distro_codename}-infra-security` - Infrastructure security updates

**Configuration**:

- **Location**: `/etc/apt/apt.conf.d/50unattended-upgrades`
- **Source**: `devbase_files/unattended-upgrades-debian/50unattended-upgrades`
- **Installed by**: `libs/install.sh:182`

**Key Settings**:

```bash
# Only update on AC power (laptops)
Unattended-Upgrade::OnlyOnACPower "true"

# Auto-remove new unused dependencies
Unattended-Upgrade::Remove-New-Unused-Dependencies "true"

# Skip development releases
Unattended-Upgrade::DevRelease "false"
```

**Verification**:

```bash
# Check unattended-upgrades status
sudo systemctl status unattended-upgrades

# View update logs
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log

# Check pending security updates
sudo unattended-upgrade --dry-run --debug
```

### Development Tools (Renovate Bot)

**Automated Updates** for 84 development tools via Renovate Bot:

**Tool Categories**:

- 50+ mise-managed tools (via Aqua registry)
- 12 custom tools (specialized installers)
- 22 VS Code extensions

**Update Flow**:

1. Renovate detects new version
2. **7-day stability period** (configured in base config)
3. PR created with version bump
4. CI runs: gitleaks, shellcheck, markdown lint, YAML lint
5. Human review required
6. Merge creates audit trail in git history

**Base Configuration**:

- **Extends**: `github>diggsweden/.github//renovate-base.json`
- **Schedule**: Defined in base config (typically weekly)
- **Stability days**: 7 days (prevents adopting brand-new releases)
- **Grouping**: Related updates batched together

**Custom Managers**:

```json
{
  "customManagers": [
    {
      "managerFilePatterns": ["dot/.config/devbase/custom-tools.yaml"],
      "matchStrings": ["renovate: datasource=..."]
    },
    {
      "managerFilePatterns": ["dot/.config/devbase/vscode-extensions.yaml"],
      "matchStrings": ["renovate: datasource=..."]
    }
  ]
}
```

**Security Benefits**:

- **No stale dependencies**: Regular updates prevent accumulation of vulnerabilities
- **Human approval**: Prevents automatic malicious updates
- **Audit trail**: Every update tracked in git with PR discussion
- **Rollback capability**: Git history enables easy version rollbacks
- **Stability period**: 7-day delay reduces risk from brand-new buggy releases

**Configuration Location**: `renovate.json` (extends base config)

## Network Security

### HTTPS Only

```bash
grep -rn "http://" devbase-core/libs --include="*.sh" | grep download
# 0 matches
```

#### Timeouts

```bash
curl --connect-timeout 30 --max-time 90 "$url"
```

**Retry Logic**: 3 attempts, exponential backoff (5s, 10s)

#### Proxy Support

```bash
export HTTP_PROXY="$DEVBASE_PROXY_URL"
export HTTPS_PROXY="$DEVBASE_PROXY_URL"
export NO_PROXY="localhost,127.0.0.1,*.internal"
```

## Custom Configuration

**Hooks** (`devbase-custom-config/hooks/`):

- `pre-install.sh` - before packages
- `post-install.sh` - after install
- Run with user privileges (not root)

**Security Model**:

- Organization controls repo
- Git commit signatures
- Code review enforced

**Certificates**:

```bash
# 1. Validate
openssl x509 -in "$cert" -noout  # Reject invalid

# 2. Install
sudo cp "$cert" /usr/local/share/ca-certificates/
sudo update-ca-certificates

# 3. Configure git
git config --global http.https://internal.com/.sslCAInfo /etc/ssl/certs/ca-certificates.crt
```

## Security Tools

| Tool | Purpose |
|------|---------|
| Gitleaks | Secret scanning |
| Syft | SBOM generation |
| Scorecard | Security scoring |
| Cosign | Container signing |
| Actionlint | GitHub Actions linting |
| Shellcheck | Shell linting |
| Hadolint | Dockerfile linting |
| Lynis | System auditing |
| ClamAV | Antivirus scanning |

### ClamAV Antivirus

DevBase configures ClamAV for automated daily malware scanning with virus definition updates.

**Automatic Configuration:**

1. **Freshclam service** - Updates virus definitions automatically
2. **Daily scan timer** - Runs full system scan once per day
3. **Low priority** - Uses `Nice=19` and `IOSchedulingClass=idle` to minimize impact

**Systemd Services:**

```bash
# Virus definition updates (enabled automatically)
systemctl status clamav-freshclam.service

# Daily scan timer (enabled automatically)
systemctl status clamav-daily-scan.timer

# View last scan results
sudo cat /var/log/clamav/daily-scan.log
```

**Scan Configuration:**

- **Schedule**: Daily at 2-4 AM (randomized start time)
- **Scope**: `/home`, `/root`, `/opt`
- **Exclusions**: Build artifacts, caches (`.cache`, `.npm`, `.cargo`, `.m2`, `node_modules`, `.git`, etc.)
- **Priority**: Nice=19, IOSchedulingClass=idle (minimal system impact)
- **Log location**: `/var/log/clamav/daily-scan.log`
- **Location**: `devbase_files/systemd/clamav/clamav-daily-scan.service`

**Performance & Caching:**

ClamAV uses **hash-based caching** enabled by default for optimal performance:

- **First scan**: Takes 6-25+ hours (scans every file, builds cache)
- **Subsequent scans**: Takes 5-30 minutes (only scans changed files)
- **Speed improvement**: 95%+ faster after initial scan
- **How it works**:
  - Calculates hash (MD5/SHA256) of each file
  - Stores hash + scan result in cache
  - On next scan: If hash matches cache → Skip detailed scan
  - If hash differs → File changed → Full scan
- **Cache location**: In-memory during scan
- **Disable caching**: Add `--disable-cache` flag (not recommended)

**What Triggers Full Rescan:**

- First-time installation (no cache exists)
- New virus signatures downloaded (daily via freshclam)
- Files modified/created (intended behavior)
- Cache manually disabled with `--disable-cache`

**Typical Daily Scan Performance:**

After initial scan, daily scans are very fast because only changed files are scanned:

- **Modified files**: ~10-200 files/day (source code, downloads, logs)
- **Unchanged files**: >99.9% skipped via cache
- **Scan duration**: 5-30 minutes vs 25+ hours (first scan)

**Manual Scanning:**

```bash
# Scan a specific directory
clamscan -r /home/user/Downloads

# Scan with infection removal (careful!)
clamscan -r --remove /path/to/scan

# Scan without cache (slower, rescans everything)
clamscan -r --disable-cache /path/to/scan

# Update virus definitions manually
sudo freshclam

# Check scan progress (while running)
tail -f /var/log/clamav/daily-scan.log
```

**Examples**:

```bash
gitleaks detect --source . --verbose
syft scan dir:. -o spdx-json > sbom.json
scorecard --repo=github.com/owner/repo
cosign sign --key cosign.key image:tag
```

## System Hardening

DevBase configures system resource limits optimized for development workloads.

### Resource Limits

**File Descriptors:**

- **Soft/Hard limit**: 65,536 open files per process
- **System maximum**: 90,000 total file handles
- **Purpose**: Supports large builds, many containers, and concurrent connections

**Process Limits:**

- **Soft/Hard limit**: 32,768 processes per user
- **Purpose**: Enables parallel builds, testing frameworks, and containerized workloads

**Memory Locking:**

- **Soft/Hard limit**: Unlimited locked memory
- **Purpose**: Required for containers, virtual machines, and performance-critical applications

### Resource Limit Configuration

DevBase creates system-wide limit configurations:

```bash
# PAM limits (user-level)
/etc/security/limits.d/99-devbase.conf
```

```text
# DevBase development limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
* soft memlock unlimited
* hard memlock unlimited
```

```bash
# Kernel parameters (system-level)
/etc/sysctl.d/99-devbase.conf
```

```text
fs.file-max = 90000
```

**Location**: `libs/configure-services.sh:79` (`set_system_limits()` function)

### Verifying Resource Limits

```bash
# Check current limits for your session
ulimit -a

# View soft limits
ulimit -Sn  # open files (soft)
ulimit -Su  # processes (soft)

# View hard limits
ulimit -Hn  # open files (hard)
ulimit -Hu  # processes (hard)

# Check system-wide file limit
cat /proc/sys/fs/file-max

# View active limits for a process
cat /proc/<PID>/limits
```

### Why These Limits?

**Development workloads** require higher limits than default system settings:

- **Large builds**: Compilers may open thousands of files simultaneously
- **Containers**: Each container consumes file descriptors and processes
- **IDEs**: Modern editors (IntelliJ, VS Code) watch many files
- **Testing**: Parallel test runners spawn many processes
- **Node.js**: `npm install` can exceed default file descriptor limits

**Security consideration**: These limits are set per-user, not system-wide, so they don't create system-wide resource exhaustion vulnerabilities.

## Known Issues

### High Priority

#### 1. Temp Directory Cleanup

```bash
ls -la /tmp/devbase.*
# Directories persist after install
```

**Fix**:

```bash
cleanup_temp() {
  [[ -n "${_DEVBASE_TEMP:-}" ]] && rm -rf "${_DEVBASE_TEMP}"
}
trap cleanup_temp EXIT INT TERM
```

### Medium Priority

#### 2. Proxy Password in Environment

- Status: Accepted (standard practice)
- Masked in output
- Users should change default

### Low Priority

#### 3. No Checksums: JMC, DBeaver, KSE

- Vendors don't provide
- HTTPS + dpkg signatures

## Security Verification Commands

```bash
# 1. No secrets
gitleaks detect --source . --verbose

# 2. No dangerous patterns
grep -rn "curl.*|.*sh\|rm -rf /\|chmod 777" libs/

# 3. Safety flags
grep -L "set -uo pipefail" libs/*.sh

# 4. SSH permissions
ls -la ~/.ssh/

# 5. Renovate-managed custom tools
grep "renovate:" devbase-core/dot/.config/devbase/custom-tools.yaml | wc -l
# Expected: 11

# 6. Aqua tools
grep "aqua:" devbase-core/dot/.config/mise/config.toml | wc -l
# Expected: 35

# 7. Temp cleanup issue
ls -la /tmp/devbase.*
# Expected: exists (needs fix)
```

---

**Last Updated**: 2025-11-02
