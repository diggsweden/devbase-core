# DevBase Security

## Summary

- ✅ Supply chain: checksums, version pinning, Renovate auto-updates
- ✅ Secrets: no hardcoded credentials, secure permissions
- ✅ Privileges: user-level install, minimal sudo
- ⚠️ Known issue: temp directory cleanup missing

## Supply Chain

### Version Management

- Single source: `devbase-core/dot/.config/devbase/versions.yaml`
- 100 tools, 79 auto-updated by Renovate, 21 manual
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

## FIPS-140-3 Compliance

DevBase is configured for FIPS-140-3 compliance by default:

### SSH Algorithms

- **Key Type**: ECDSA P-521 (521-bit elliptic curve)
- **Ciphers**: AES-256-GCM, AES-128-GCM
- **MACs**: HMAC-SHA2-512-ETM, HMAC-SHA2-256-ETM
- **Key Exchange**: ECDH-SHA2-NISTP521, DH-Group18-SHA512, DH-Group16-SHA512, ECDH-SHA2-NISTP384
- **Host Key Algorithms**: ECDSA-SHA2-NISTP521, RSA-SHA2-512, ECDSA-SHA2-NISTP384
- **Public Key Types**: ECDSA-SHA2-NISTP521, RSA-SHA2-512, ECDSA-SHA2-NISTP384

### Configuration Files

- `~/.ssh/fips-client.config` - FIPS with fallbacks (default)
- `~/.ssh/fips-strong-client.config` - Strongest algorithms only

To use strongest-only algorithms, edit `~/.ssh/config` and change:

```bash
Include ~/.ssh/fips-client.config
```

to:

```bash
Include ~/.ssh/fips-strong-client.config
```

### Testing FIPS Compliance

```bash
# Verify SSH connection uses FIPS algorithms
ssh -vvv git@github.com 2>&1 | grep -E "kex:|cipher:|MAC:"

# Check loaded key type
ssh-add -l

# Test connection
ssh -T git@github.com
ssh -T git@gitlab.com
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

# Look for FIPS algorithms in output:
# - kex: algorithm: ecdh-sha2-nistp521
# - cipher: aes256-gcm@openssh.com
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

DevBase generates ECDSA P-521 keys (FIPS-140-3 compliant):

- Private key: `~/.ssh/id_ecdsa_nistp521_devbase`
- Public key: `~/.ssh/id_ecdsa_nistp521_devbase.pub`

### Why ECDSA P-521?

- **FIPS-140-3 compliant**: Required for government and enterprise environments
- **Widely supported**: All major Git hosting services (GitHub, GitLab, Bitbucket)
- **Strong security**: 521-bit NIST curve provides robust cryptographic strength
- **Policy compatible**: Works with strict SSH security policies

## File Permissions

| Resource | Permission |
|----------|-----------|
| SSH private keys (ECDSA P-521) | 600 |
| SSH public keys | 644 |
| SSH directory | 700 |
| SSH config | 600 |
| FIPS config files | 644 |
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

**No Dangerous Patterns**:

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

**Examples**:

```bash
gitleaks detect --source . --verbose
syft scan dir:. -o spdx-json > sbom.json
scorecard --repo=github.com/owner/repo
cosign sign --key cosign.key image:tag
```

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

## Verification

```bash
# 1. No secrets
gitleaks detect --source . --verbose

# 2. No dangerous patterns
grep -rn "curl.*|.*sh\|rm -rf /\|chmod 777" libs/

# 3. Safety flags
grep -L "set -uo pipefail" libs/*.sh

# 4. SSH permissions
ls -la ~/.ssh/

# 5. Renovate tools
grep "renovate:" devbase-core/dot/.config/devbase/versions.yaml | wc -l
# Expected: 79

# 6. Aqua tools
grep "aqua:" devbase-core/dot/.config/mise/config.toml | wc -l
# Expected: 35

# 7. Temp cleanup issue
ls -la /tmp/devbase.*
# Expected: exists (needs fix)
```

---

**Last Updated**: 2025-10-27
