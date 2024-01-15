#!/usr/bin/env bash
set -uo pipefail

# DevBase Installation Verification Script
# Run after installation to verify all components are properly set up

# Auto-detect CI environment if NON_INTERACTIVE not already set
# This ensures warnings cause failures in CI (requires 100% pass rate)
if [[ -z "${NON_INTERACTIVE:-}" ]]; then
  if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]] || [[ -n "${JENKINS_URL:-}" ]] || [[ -n "${GITLAB_CI:-}" ]]; then
    export NON_INTERACTIVE=true
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/verify-base-lib.sh" ]]; then
  source "${SCRIPT_DIR}/verify-base-lib.sh"
else
  echo "Error: verify-base-lib.sh not found"
  exit 1
fi

# SSH config box width (specific to this script)
readonly SSH_CONFIG_BOX_WIDTH=43
readonly MAX_TREE_DISPLAY_LINES=30
readonly MAX_TEMPLATE_DISPLAY=10
readonly MAX_CUSTOM_TEMPLATES_DISPLAY=5

# Time constants
readonly CERT_EXPIRY_WARNING_DAYS=120
readonly CERT_EXPIRY_WARNING_SECONDS=$((CERT_EXPIRY_WARNING_DAYS * 86400))

# Comment skip patterns
readonly SKIP_SHELL_COMMENTS="^[[:space:]]*#"
readonly SKIP_XML_COMMENTS="^[[:space:]]*\<\!--\|^[[:space:]]*--\>"

# Path constants
readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
readonly LOCAL_BIN="$HOME/.local/bin"

# System paths
readonly SYSTEM_CA_CERTS="/usr/local/share/ca-certificates"
readonly SYSTEM_SSL_CERTS="/etc/ssl/certs"
readonly SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
readonly RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# DevBase specific paths
readonly DEVBASE_CONFIG="$CONFIG_HOME/devbase"
readonly DEVBASE_CACHE="$CACHE_HOME/devbase"
readonly MISE_CONFIG="$CONFIG_HOME/mise/config.toml"
readonly MISE_SHIMS="$DATA_HOME/mise/shims"

# Development paths
readonly DEV_HOME="${HOME}/development"
readonly NOTES_HOME="${HOME}/notes"

# Common config files
readonly GITCONFIG="$HOME/.gitconfig"
readonly GIT_CONFIG="$CONFIG_HOME/git/config"
readonly SSH_CONFIG="$HOME/.ssh/config"
readonly FISH_CONFIG="$CONFIG_HOME/fish/config.fish"
readonly MAVEN_HOME="$HOME/.m2"
readonly MAVEN_SETTINGS="$MAVEN_HOME/settings.xml"
readonly GRADLE_HOME="$HOME/.gradle"
readonly GRADLE_PROPERTIES="$GRADLE_HOME/gradle.properties"

# Message templates
readonly MSG_NOT_FOUND="%s not found"
readonly MSG_NOT_INSTALLED="%s is not installed"
readonly MSG_NOT_CONFIGURED="%s not configured"
readonly MSG_FILE_MISSING="%s missing (%s)"
readonly MSG_PERMISSION_ERROR="%s: %s (expected %s)"
readonly MSG_SECURITY_RISK="SECURITY RISK"
readonly MSG_FIX_PERMISSION="Fix with: chmod %s %s"
readonly MSG_RUN_COMMAND="Run: %s"
readonly MSG_INSTALLED="%s installed"
readonly MSG_VERSION="%s (version: %s)"
readonly MSG_CONFIG_EXISTS="%s exists"

# Counters initialized in verify-base-lib.sh

# Note: extract_version() and parse_mise_tool() functions removed - dead code (not used anywhere)

get_permissions() {
  stat -c %a "$1" 2>/dev/null || echo "missing"
}

count_files() {
  local dir="$1"
  local pattern="${2:-*}"
  find "$dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | wc -l
}

# check_file_content now in verify-base-lib.sh

# Configuration - Expected Tools and Packages

# APT packages expected (from libs/install-apt.sh)
declare -A APT_PACKAGES=(
  ["apt-utils"]="required"
  ["bash-completion"]="required"
  ["build-essential"]="required"
  ["buildah"]="optional"
  ["clamav"]="optional"
  ["clamav-daemon"]="optional"
  ["containernetworking-plugins"]="optional"
  ["curl"]="required"
  ["default-jdk"]="optional"
  ["default-jre"]="optional"
  ["desktop-file-utils"]="optional"
  ["dislocker"]="optional"
  ["dnsutils"]="optional"
  ["e2fsprogs"]="required"
  ["fish"]="required"
  ["git"]="required"
  ["libgbm1"]="optional"
  ["libnss3-tools"]="optional"
  ["locales"]="required"
  ["vifm"]="optional"
  ["mkcert"]="optional"
  ["openssh-client"]="required"
  ["pandoc"]="optional"
  ["parallel"]="optional"
  ["podman"]="optional"
  ["pwgen"]="optional"
  ["python3"]="required"
  ["python3-dev"]="optional"
  ["python3-venv"]="optional"
  ["skopeo"]="optional"
  ["ssh-askpass"]="optional"
  ["tree"]="optional"
  ["unattended-upgrades"]="optional"
  ["visualvm"]="optional"
  ["wget"]="required"
  ["xdg-desktop-portal-gtk"]="optional"
  ["yadm"]="optional"
)

# Mise-managed tools
# CLI tools that should be available
# CLI_TOOLS removed - these are already checked as APT packages
# No need to check them twice

# Common Utility Functions now in verify-base-lib.sh

# Note: check_file_exists() and check_dir_exists() removed - dead code
# Code now uses file_exists() and dir_exists() directly

get_file_permissions() {
  local file="$1"
  if [[ -e "$file" ]]; then
    get_permissions "$file"
  else
    echo "missing"
  fi
}

check_permissions() {
  local path="$1"
  local expected="$2"
  local type="${3:-file}"
  local display_path=$(normalize_path "$path")

  if [[ ! -e "$path" ]]; then
    printf "  %b%s%b %s - missing\n" "${RED}" "$CROSS" "${NC}" "$display_path"
    return 1
  fi

  local actual=$(get_file_permissions "$path")
  if [[ "$actual" == "$expected" ]]; then
    printf "  %b%s%b %s: %s\n" "${GREEN}" "$CHECK" "${NC}" "$display_path" "$actual"
    return 0
  else
    if [[ "$type" == "dir" && "$path" == "$HOME/.ssh" && "$actual" != "700" ]]; then
      printf "  %b%s%b %s: %s (should be 700) - %bSECURITY RISK%b\n" \
        "${RED}" "$CROSS" "${NC}" "$display_path" "$actual" "${RED}" "${NC}"
      printf "    %b→ Fix with: chmod 700 %s%b\n" "${DIM}" "$path" "${NC}"
    elif [[ "$type" == "file" && "$path" =~ id_ecdsa_nistp521 && "$actual" != "600" ]]; then
      printf "  %b%s%b %s: %s (should be 600) - %bKEY EXPOSED%b\n" \
        "${RED}" "$CROSS" "${NC}" "$display_path" "$actual" "${RED}" "${NC}"
      printf "    %b→ Fix with: chmod 600 %s%b\n" "${DIM}" "$path" "${NC}"
    else
      printf "  %b%s%b %s: %s (expected %s)\n" \
        "${YELLOW}" "$WARN" "${NC}" "$display_path" "$actual" "$expected"
    fi
    return 1
  fi
}

# Configuration: Expected Files and Directories

# Core directories that should exist
readonly -a DEVBASE_CORE_DIRS=(
  "$CONFIG_HOME"
  "$SYSTEMD_USER_DIR"
  "$LOCAL_BIN"
  "$DATA_HOME"
  "$CACHE_HOME"
)

# DevBase-specific directories
readonly -a DEVBASE_SPECIFIC_DIRS=(
  "$DEVBASE_CONFIG"
  "$DEVBASE_CACHE"
  "$HOME/.ssh"
  "$CONFIG_HOME/ssh"
)

# Tool configuration directories
readonly -a TOOL_CONFIG_DIRS=(
  "$CONFIG_HOME/fish"
  "$CONFIG_HOME/fish/completions"
  "$CONFIG_HOME/fish/conf.d"
  "$CONFIG_HOME/mise"
  "$CONFIG_HOME/git"
  "$CONFIG_HOME/nvim/lua/plugins"
  "$CONFIG_HOME/starship"
  "$CONFIG_HOME/zellij"
  "$CONFIG_HOME/containers"
)

# Expected permissions for sensitive directories
declare -A DIR_PERMISSIONS=(
  ["$HOME/.ssh"]="700"
  ["$HOME/.config/ssh"]="755"
)

# Expected permissions for sensitive files
declare -A FILE_PERMISSIONS=(
  ["$HOME/.ssh/config"]="600"
  ["$HOME/.ssh/id_ecdsa_nistp521_devbase"]="600"
  ["$HOME/.ssh/id_ecdsa_nistp521_devbase.pub"]="644"
)

# Enhanced Utility Functions

# check_env_var now in verify-base-lib.sh

# Note: The following functions have been removed as dead code (not used anywhere):
# - check_systemd_service() - Systemd services are checked directly in check_systemd_services()
# - display_git_config() - Git config display logic is now inlined in check_git_config()
# - check_file_exists() and check_dir_exists() - Code now uses file_exists() and dir_exists() directly
# - parse_config_line() - Not used anywhere
# - check_paths() - Not used anywhere
# - safe_check() - Not used anywhere
# - check_file_permissions() - Not used anywhere
# - check_command() and check_command_status() - Not used anywhere

check_git_config() {
  print_header "5. Git Configuration"

  # Check ~/.gitconfig first
  if file_exists "$GITCONFIG"; then
    printf "\n  %b~/.gitconfig:%b\n" "${BOLD}" "${NC}"
    local gitconfig_output=$(git config --list --file="$GITCONFIG" 2>/dev/null | sort)

    if [[ -n "$gitconfig_output" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local key=$(echo "$line" | cut -d'=' -f1)
        local value=$(echo "$line" | cut -d'=' -f2-)

        # Handle special value types
        if [[ "$value" =~ ^/ ]]; then
          value=$(normalize_path "$value")
        fi

        # Truncate very long values
        if [[ ${#value} -gt $MAX_VALUE_LENGTH ]]; then
          if [[ "$value" =~ ^ssh- ]]; then
            # SSH keys are long - show only key type (first field) and email (last field)
            # Example: "ssh-ed25519 AAAA...long_key user@host" -> "ssh-ed25519 ...user@host"
            local key_type=$(awk '{print $1}' <<<"$value")
            local key_email=$(awk '{print $NF}' <<<"$value")
            value="$key_type ...$key_email"
          else
            value=$(truncate_string "$value")
          fi
        fi

        print_check "pass" "$key = $value"
      done <<<"$gitconfig_output"
    else
      printf "  %b%s%b (empty)\n" "${GRAY}" "$INFO" "${NC}"
    fi
  else
    printf "\n  %b~/.gitconfig:%b\n" "${BOLD}" "${NC}"
    print_check "fail" "$(printf '%s not found or empty' "$HOME/.gitconfig")"
  fi

  # Check ~/.config/git/config
  local git_config_dir="$CONFIG_HOME/git/config"
  if file_exists "$git_config_dir"; then
    printf "\n  %b~/.config/git/config:%b\n" "${BOLD}" "${NC}"
    local config_output=$(git config --list --file="$git_config_dir" 2>/dev/null | sort)

    if [[ -n "$config_output" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local key=$(echo "$line" | cut -d'=' -f1)
        local value=$(echo "$line" | cut -d'=' -f2-)

        # Handle special value types
        if [[ "$value" =~ ^/ ]]; then
          value=$(normalize_path "$value")
        fi

        # Truncate very long values
        if [[ ${#value} -gt $MAX_VALUE_LENGTH ]]; then
          if [[ "$value" =~ ^ssh- ]]; then
            # SSH keys are long - show only key type (first field) and email (last field)
            # Example: "ssh-ed25519 AAAA...long_key user@host" -> "ssh-ed25519 ...user@host"
            local key_type=$(awk '{print $1}' <<<"$value")
            local key_email=$(awk '{print $NF}' <<<"$value")
            value="$key_type ...$key_email"
          else
            value=$(truncate_string "$value")
          fi
        fi

        print_check "pass" "$key = $value"
      done <<<"$config_output"
    else
      printf "  %b%s%b (empty)\n" "${GRAY}" "$INFO" "${NC}"
    fi
  else
    printf "\n  %b~/.config/git/config:%b\n" "${BOLD}" "${NC}"
    print_check "fail" "File not found"
  fi
}

# Check SSH configuration
# Check SSH keys
check_ssh_keys() {
  local ssh_keys=(
    "id_ecdsa_nistp521_devbase"
    "id_ecdsa_nistp521_devbase.pub"
  )

  for key in "${ssh_keys[@]}"; do
    local key_path="$HOME/.ssh/$key"
    local display_path=$(normalize_path "$key_path")

    if file_exists "$key_path"; then
      local perms=$(get_file_permissions "$key_path")
      local expected_perms="600"
      [[ "$key" == *.pub ]] && expected_perms="644"

      if [[ "$perms" == "$expected_perms" ]] || ([[ "$key" == *.pub ]] && [[ "$perms" == "600" ]]); then
        print_check "pass" "$key exists, perms: $perms ($display_path)"
      else
        print_check "warn" "$key has incorrect permissions: $perms - should be $expected_perms ($display_path)"
      fi
    else
      print_check "warn" "$key missing ($display_path)"
    fi
  done
}

# Display SSH config file content
display_ssh_config_content() {
  local config_file="$1"
  local max_lines="${2:-20}"
  local title="${3:-Main SSH Config}"

  printf "\n  %b%s:%b\n" "${BOLD}" "$title" "${NC}"
  printf "  %b┌─────────────────────────────────────────────┐%b\n" "${DIM}" "${NC}"

  local line_count=0
  while IFS= read -r line && [[ $line_count -lt $max_lines ]]; do
    # Skip empty lines and full comment lines
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    printf "  %b│ %-*s │%b\n" "${DIM}" "$SSH_CONFIG_BOX_WIDTH" "${line:0:$SSH_CONFIG_BOX_WIDTH}" "${NC}"
    line_count=$((line_count + 1))
  done <"$config_file"

  [[ $line_count -eq 0 ]] && printf "  %b│ %-43s │%b\n" "${DIM}" "(empty or only comments)" "${NC}"
  printf "  %b└─────────────────────────────────────────────┘%b\n" "${DIM}" "${NC}"
}

# Check SSH Include directives
check_ssh_includes() {
  # Extract Include paths from SSH config (second field after "Include")
  local includes=$(grep "^Include" "$SSH_CONFIG" 2>/dev/null |
    awk '{print $2}')
  [[ -z "$includes" ]] && return 0

  for include_pattern in $includes; do
    # Expand tilde
    include_pattern="${include_pattern/#\~/$HOME}"

    local found_files=false
    for include_file in $include_pattern; do
      if file_exists "$include_file"; then
        found_files=true
        display_ssh_config_content "$include_file" 15 "Included: ${include_file/#$HOME/~}"
      fi
    done

    if [[ "$found_files" == "false" ]]; then
      printf "\n  %bInclude: %s%b\n" "${BOLD}" "${include_pattern/#$HOME/~}" "${NC}"

      # Determine severity based on file type
      if [[ "$include_pattern" == *"custom.config"* ]]; then
        # custom.config is optional (only exists if customization provides it)
        printf "  %b%s%b File not found (optional - only if customization provides it)%b\n" "${GRAY}" "$INFO" "${NC}" "${NC}"
      elif [[ "$include_pattern" == *"user.config"* ]]; then
        # user.config is optional (created empty, user adds hosts)
        printf "  %b%s%b File not found (optional - for personal SSH hosts)%b\n" "${GRAY}" "$INFO" "${NC}" "${NC}"
      elif [[ "$include_pattern" == *"*"* ]]; then
        # Wildcard patterns - info only
        printf "  %b%s%b No matching files found%b\n" "${GRAY}" "$INFO" "${NC}" "${NC}"
      else
        # Other includes - warning
        printf "  %b%s%b File not found%b\n" "${YELLOW}" "$WARN" "${NC}" "${NC}"
      fi
    fi
  done
}

# Check DevBase SSH settings
check_devbase_ssh_settings() {
  printf "\n  %bDevBase SSH Template Settings:%b\n" "${BOLD}" "${NC}"
  printf "  %b(From dot/.ssh/config template)%b\n" "${DIM}" "${NC}"

  local devbase_settings=(
    "AddKeysToAgent:yes:Automatically adds SSH keys to agent when used"
    "StrictHostKeyChecking:yes:Always verifies host keys (most secure)"
    "VisualHostKey:yes:Shows ASCII art representation of host key fingerprint"
  )

  for setting_desc in "${devbase_settings[@]}"; do
    local setting="${setting_desc%%:*}"
    local temp="${setting_desc#*:}"
    local expected="${temp%%:*}"
    local description="${temp#*:}"
    # Extract value (second field) from SSH config for this setting
    local value=$(grep -E "^[[:space:]]*${setting}" "$SSH_CONFIG" 2>/dev/null |
      head -1 |
      awk '{print $2}')

    if [[ -n "$value" ]]; then
      if [[ "$value" == "$expected" ]]; then
        printf "    %b✓%b %s = %s\n" "${GREEN}" "${NC}" "$setting" "$value"
      else
        printf "    %b%s%b %s = %s (DevBase sets: %s)\n" "${YELLOW}" "$WARN" "${NC}" "$setting" "$value" "$expected"
      fi
    else
      printf "    %b%s%b %s not set (DevBase default: %s)\n" "${GRAY}" "$INFO" "${NC}" "$setting" "$expected"
    fi
    printf "      %b→%b %s\n" "${DIM}" "${NC}" "$description"
  done

  # Check Host entries
  local host_count=$(grep -c "^Host " "$SSH_CONFIG" 2>/dev/null || echo 0)
  [[ $host_count -gt 0 ]] && printf "    %b%s%b Host entries: %d configured\n" "${CYAN}" "$INFO" "${NC}" "$host_count"
}

check_ssh_config() {
  print_header "6. SSH Configuration"

  check_ssh_keys

  # Early return if no SSH config
  if ! file_exists "$SSH_CONFIG"; then
    print_check "warn" "SSH config missing (~/.ssh/config)"
    return 1
  fi

  print_check "pass" "SSH config exists (~/.ssh/config)"

  # Display main config
  display_ssh_config_content "$SSH_CONFIG" 20 "Main SSH Config (~/.ssh/config)"

  # Check FIPS config files
  printf "\n  %bFIPS-140-3 Configuration:%b\n" "${BOLD}" "${NC}"

  if file_exists ~/.ssh/fips-client.config; then
    print_check "pass" "FIPS client config exists (~/.ssh/fips-client.config)"
  else
    print_check "warn" "FIPS client config missing (~/.ssh/fips-client.config)"
  fi

  if file_exists ~/.ssh/fips-strong-client.config; then
    print_check "pass" "FIPS strong config exists (~/.ssh/fips-strong-client.config)"
  else
    print_check "warn" "FIPS strong config missing (~/.ssh/fips-strong-client.config)"
  fi

  # Check which FIPS config is active
  if grep -q "^Include.*fips-client.config" "$SSH_CONFIG" 2>/dev/null; then
    print_check "pass" "FIPS client config active (with fallbacks)"
  elif grep -q "^Include.*fips-strong-client.config" "$SSH_CONFIG" 2>/dev/null; then
    print_check "pass" "FIPS strong config active (strongest only)"
  else
    print_check "warn" "No FIPS config included in SSH config"
  fi

  # Check HashKnownHosts setting
  if grep -q "^[[:space:]]*HashKnownHosts yes" "$SSH_CONFIG" 2>/dev/null; then
    print_check "pass" "HashKnownHosts enabled (enhanced security)"
  else
    print_check "info" "HashKnownHosts not enabled"
  fi

  # Check includes
  check_ssh_includes

  # Check if Include directives exist
  if grep -q "Include.*custom.config" "$SSH_CONFIG" 2>/dev/null; then
    if file_exists ~/.config/ssh/custom.config; then
      print_check "pass" "Custom SSH config included and exists"
    else
      print_check "info" "Custom SSH config include present (file optional)"
    fi
  fi

  if grep -q "Include.*user.config" "$SSH_CONFIG" 2>/dev/null; then
    if file_exists ~/.config/ssh/user.config; then
      local line_count=$(grep -ve '^#' -e '^[[:space:]]*$' ~/.config/ssh/user.config 2>/dev/null | wc -l)
      if [[ "$line_count" -gt 0 ]]; then
        print_check "pass" "User SSH config has $line_count host entries"
      else
        print_check "info" "User SSH config exists (empty - add personal hosts)"
      fi
    else
      print_check "warn" "User SSH config missing"
    fi
  fi

  # Check DevBase settings
  check_devbase_ssh_settings
}

# Check shell integrations (DevBase only configures Fish)
check_shell_integrations() {
  print_header "7. Shell Integrations"

  # DevBase only sets up Fish shell integrations, not Bash
  # Check fish integration
  if file_exists "$FISH_CONFIG"; then
    # Check mise integration
    if grep -q 'mise activate fish' "$FISH_CONFIG" 2>/dev/null ||
      file_exists "$CONFIG_HOME/fish/conf.d/mise.fish"; then
      print_check "pass" "Mise integrated with fish (~/.config/fish/config.fish)"
    else
      print_check "warn" "Mise not integrated with fish"
    fi

    # Check starship integration
    check_file_content "$FISH_CONFIG" "starship init fish" \
      "Starship integrated with fish (~/.config/fish/config.fish)" \
      "Starship not integrated with fish" "warn"

    # Check Zellij autostart configuration (set in 00-environment.fish)
    local env_fish="$CONFIG_HOME/fish/conf.d/00-environment.fish"
    if [[ -f "$env_fish" ]]; then
      # Read the actual value from the generated config
      local zellij_autostart
      zellij_autostart=$(grep 'set -gx DEVBASE_ZELLIJ_AUTOSTART' "$env_fish" 2>/dev/null | awk '{print $4}' | tr -d '"')

      if [[ "$zellij_autostart" == "true" ]]; then
        print_check "pass" "Zellij autostart enabled"
      else
        print_check "info" "Zellij autostart disabled (DEVBASE_ZELLIJ_AUTOSTART=$zellij_autostart)"
      fi
    else
      print_check "warn" "Zellij autostart not configured (00-environment.fish not found)"
    fi

    # Check if fish functions exist
    if dir_exists "$CONFIG_HOME/fish/functions"; then
      local func_count=$(count_files "$CONFIG_HOME/fish/functions")
      if [[ $func_count -gt 0 ]]; then
        print_check "pass" "Fish functions installed ($func_count functions)"
      fi
    fi

    # Check if fish conf.d exists
    if dir_exists "$CONFIG_HOME/fish/conf.d"; then
      local conf_count=$(count_files "$CONFIG_HOME/fish/conf.d")
      if [[ $conf_count -gt 0 ]]; then
        print_check "pass" "Fish conf.d configured ($conf_count config files)"
      fi
    fi
  else
    print_check "warn" "Fish config not found (~/.config/fish/config.fish)"
  fi
}

# Check network and proxy settings
# REMOVED: This is now shown in Environment Variables section
# check_network_settings() {
#     print_header "8. Network & Proxy Settings"
#
#     # Check if proxy variables are set
#     local proxy_vars=(
#         "HTTP_PROXY"
#         "HTTPS_PROXY"
#         "NO_PROXY"
#     )
#
#     local has_proxy=false
#     for var in "${proxy_vars[@]}"; do
#         if [[ -n "${!var:-}" ]]; then
#             local value="${!var}"
#             # Truncate long values for display
#             if [[ ${#value} -gt 50 ]]; then
#                 value="${value:0:47}..."
#             fi
#             print_check "info" "$var: $value"
#             has_proxy=true
#         fi
#     done
#
#     if [[ "$has_proxy" == "false" ]]; then
#         print_check "info" "No proxy configured"
#     fi
#
#     # Check Docker proxy settings if Docker is installed
#     if command -v docker &>/dev/null; then
#         if [[ -f "$HOME/.docker/config.json" ]]; then
#             if grep -q "proxies" "$HOME/.docker/config.json" 2>/dev/null; then
#                 print_check "pass" "Docker proxy configured"
#             else
#                 print_check "info" "Docker proxy not configured"
#             fi
#         fi
#     fi
# }

# Check installed certificates

# Check APT packages
check_apt_packages() {
  print_subheader "APT Packages"

  local apt_installed=0
  local apt_total=0

  # Sort package names for consistent output
  local sorted_packages
  mapfile -t sorted_packages < <(for pkg in "${!APT_PACKAGES[@]}"; do echo "$pkg"; done | sort)

  for pkg in "${sorted_packages[@]}"; do
    apt_total=$((apt_total + 1))
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
      apt_installed=$((apt_installed + 1))
      print_check "pass" "$pkg"
    else
      print_check "fail" "$pkg"
    fi
  done

  # Store results for summary
  APT_INSTALLED_COUNT=$apt_installed
  APT_TOTAL_COUNT=$apt_total
}

# Check CLI tools
# Removed check_cli_tools - these tools are already checked as APT packages

# Check mise managed tools
check_mise_tools() {
  print_subheader "Mise Tools"

  # Read expected tools from mise config.toml (not custom-tools.yaml)
  local mise_config="$CONFIG_HOME/mise/config.toml"
  if ! file_exists "$mise_config"; then
    mise_config="${DEVBASE_ROOT:-$(pwd)}/dot/.config/mise/config.toml"
  fi

  local mise_installed=0
  local mise_total=0

  if file_exists "$mise_config" && command -v mise &>/dev/null; then
    # Get installed mise tools formatted as "tool@version"
    local installed_tools=$(mise list 2>/dev/null |
      awk '{print $1 "@" $2}')

    # Collect all tools first for sorting
    declare -A tool_info
    declare -a tool_names

    # Parse config.toml for expected tools
    # Format: tool = "version" OR "prefix:org/tool" = "version"
    while IFS= read -r line; do
      # Skip comments, empty lines, and config settings
      [[ "$line" =~ ^#.*$ ]] && continue
      [[ -z "$line" ]] && continue
      [[ "$line" =~ ^(experimental|legacy_version_file|asdf_compat|jobs|yes|http_timeout) ]] && continue

      # Split on first = only (avoid splitting on = inside brackets like [provider=gitlab,exe=glab])
      local tool_spec="${line%%=*}"
      local version_spec="${line#*=}"

      # Clean up tool_spec (handle quotes and brackets)
      local tool=$(echo "$tool_spec" | tr -d '"' | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')
      # Clean up version_spec (handle quotes and comments)
      local expected_version=$(echo "$version_spec" | tr -d '"' | awk '{print $1}' | sed 's/^[[:space:]]*//')

      # Extract short name from aqua/ubi/github prefixes
      # "aqua:org/tool" -> "tool"
      # "ubi:tool/tool[options]" -> "tool"
      # "github:org/tool" -> "tool"
      if [[ "$tool" =~ : ]]; then
        tool=$(echo "$tool" | sed 's/.*://' | sed 's/.*\///' | sed 's/\[.*//')
      fi

      # Skip empty or invalid entries
      [[ -z "$tool" ]] && continue
      [[ -z "$expected_version" ]] && continue

      tool_info["$tool"]="$expected_version"
      tool_names+=("$tool")
    done < <(grep -E "^[a-z\"]+.*=" "$mise_config" | grep -v "^#")

    # Sort tool names
    local sorted_tools
    mapfile -t sorted_tools < <(printf '%s\n' "${tool_names[@]}" | sort)

    # Display sorted tools and count them
    for tool in "${sorted_tools[@]}"; do
      local expected_version="${tool_info[$tool]}"
      mise_total=$((mise_total + 1))

      # Check if tool is installed
      # Handle different tool naming formats:
      # - Standard: toolname@version
      # - Aqua/UBI: prefix:org/toolname@version or prefix:toolname/toolname@version
      if echo "$installed_tools" | grep -qE "^$tool@|^.*:.*$tool.*@|^.*/$tool@"; then
        mise_installed=$((mise_installed + 1))
        printf "  %b%s%b %s %b(%s)%b\n" "${GREEN}" "$CHECK" "${NC}" "$tool" "${DIM}" "$expected_version" "${NC}"
      else
        # Check if tool exists by command
        if has_command "$tool"; then
          mise_installed=$((mise_installed + 1))
          printf "  %b%s%b %s installed %b(%s)%b\n" "${GREEN}" "$CHECK" "${NC}" "$tool" "${DIM}" "$expected_version" "${NC}"
        else
          printf "  %b%s%b %s %b(%s)%b\n" "${RED}" "$CROSS" "${NC}" "$tool" "${DIM}" "$expected_version" "${NC}"
        fi
      fi
    done

    # Store results for summary
    MISE_INSTALLED_COUNT=$mise_installed
    MISE_TOTAL_COUNT=$mise_total
  else
    MISE_INSTALLED_COUNT=0
    MISE_TOTAL_COUNT=0
  fi
}

# Check snap packages
check_snap_packages() {
  print_subheader "Snap Packages"

  if ! command -v snap &>/dev/null; then
    print_check "info" "snapd not installed"
    SNAP_INSTALLED_COUNT=0
    SNAP_TOTAL_COUNT=0
    return 0
  fi

  local snap_installed=0
  local snap_total=0

  # Snap packages are managed by install-snap.sh, not custom-tools.yaml
  local snap_tools=(ghostty firefox chromium microk8s)

  for snap in "${snap_tools[@]}"; do
    snap_total=$((snap_total + 1))
    if snap list "$snap" &>/dev/null; then
      snap_installed=$((snap_installed + 1))
      local snap_version=$(snap list "$snap" 2>/dev/null | awk 'NR==2 {print $2}')
      printf "  %b%s%b %s %b(%s)%b\n" "${GREEN}" "$CHECK" "${NC}" "$snap" "${DIM}" "$snap_version" "${NC}"
    else
      print_check "fail" "$snap"
    fi
  done

  SNAP_INSTALLED_COUNT=$snap_installed
  SNAP_TOTAL_COUNT=$snap_total
}

# Check custom installed tools
check_custom_tools() {
  print_subheader "Custom Tools"

  local custom_installed=0
  local custom_total=0

  # Fisher (Fish plugin manager)
  custom_total=$((custom_total + 1))
  if has_command fish && fish -c "type -q fisher" 2>/dev/null; then
    print_check "pass" "Fisher (Fish plugin manager)"
    custom_installed=$((custom_installed + 1))
  else
    print_check "info" "Fisher not installed (Fish plugin manager)"
  fi

  # fzf.fish (Fisher plugin)
  custom_total=$((custom_total + 1))
  if has_command fish && fish -c "fisher list" 2>/dev/null | grep -iq "fzf.fish"; then
    print_check "pass" "fzf.fish (FZF Fish integration)"
    custom_installed=$((custom_installed + 1))
  else
    print_check "info" "fzf.fish not installed (FZF keybindings for Fish)"
  fi

  # LazyVim
  custom_total=$((custom_total + 1))
  if [[ -f "${HOME}/.config/nvim/lua/config/lazy.lua" ]] &&
    grep -q "LazyVim/LazyVim" "${HOME}/.config/nvim/lua/config/lazy.lua" 2>/dev/null; then
    print_check "pass" "LazyVim (Neovim starter config)"
    custom_installed=$((custom_installed + 1))
  else
    print_check "fail" "LazyVim (Neovim starter config)"
  fi

  # JDK Mission Control
  custom_total=$((custom_total + 1))
  if has_command "jmc" || [[ -d "${HOME}/.local/share/jmc" ]]; then
    print_check "pass" "JDK Mission Control (Java profiler)"
    custom_installed=$((custom_installed + 1))
  else
    print_check "info" "JDK Mission Control (optional, not installed)"
  fi

  # IntelliJ IDEA
  custom_total=$((custom_total + 1))
  if has_command "idea" || [[ -d "${HOME}/.local/share/JetBrains/Toolbox" ]] || [[ -d "${HOME}/.local/share/intellij-idea" ]]; then
    print_check "pass" "IntelliJ IDEA Ultimate"
    custom_installed=$((custom_installed + 1))
  else
    print_check "info" "IntelliJ IDEA Ultimate (optional, not installed)"
  fi

  # VS Code
  custom_total=$((custom_total + 1))
  if has_command "code"; then
    print_check "pass" "VS Code (Code editor)"
    custom_installed=$((custom_installed + 1))
  else
    print_check "info" "VS Code (optional, not installed)"
  fi

  # DBeaver
  custom_total=$((custom_total + 1))
  if has_command "dbeaver" || [[ -f "${HOME}/.local/bin/dbeaver" ]]; then
    print_check "pass" "DBeaver (Database tool)"
    custom_installed=$((custom_installed + 1))
  else
    print_check "info" "DBeaver (optional, not installed)"
  fi

  # KeyStore Explorer
  custom_total=$((custom_total + 1))
  if has_command "kse" || [[ -f "${HOME}/.local/bin/kse" ]]; then
    print_check "pass" "KeyStore Explorer (Java keystore tool)"
    custom_installed=$((custom_installed + 1))
  else
    print_check "info" "KeyStore Explorer (optional, not installed)"
  fi

  # OpenShift CLI (oc) and kubectl
  custom_total=$((custom_total + 1))
  if has_command "oc" && has_command "kubectl"; then
    print_check "pass" "OpenShift CLI (oc) and kubectl"
    custom_installed=$((custom_installed + 1))
  else
    print_check "info" "OpenShift CLI (oc) and kubectl (optional, not installed)"
  fi

  CUSTOM_INSTALLED_COUNT=$custom_installed
  CUSTOM_TOTAL_COUNT=$custom_total
}

# Main installed tools check
check_installed_tools() {
  print_header "8. Installed Tools"

  # Run checks with full output
  check_apt_packages
  check_snap_packages
  check_mise_tools
  check_custom_tools

  # Simple summary
  printf "\n"
  printf "  %bAPT: %d/%d installed%b\n" "${CYAN}" "${APT_INSTALLED_COUNT:-0}" "${APT_TOTAL_COUNT:-0}" "${NC}"
  printf "  %bSnap: %d/%d installed%b\n" "${CYAN}" "${SNAP_INSTALLED_COUNT:-0}" "${SNAP_TOTAL_COUNT:-0}" "${NC}"
  printf "  %bMise: %d/%d installed%b\n" "${CYAN}" "${MISE_INSTALLED_COUNT:-0}" "${MISE_TOTAL_COUNT:-0}" "${NC}"
  printf "  %bCustom: %d/%d installed%b\n" "${CYAN}" "${CUSTOM_INSTALLED_COUNT:-0}" "${CUSTOM_TOTAL_COUNT:-0}" "${NC}"
}

# Simplified - functionality moved to check_installed_tools
# Check VS Code extensions
check_vscode_extensions() {
  print_header "9. VS Code Extensions"

  # Check if VS Code is available
  local code_cmd=""
  local remote_flag=""

  if command -v code &>/dev/null; then
    code_cmd="code"
  elif [[ -f "/usr/bin/code" ]]; then
    # VS Code installed via .deb but not yet in PATH
    code_cmd="/usr/bin/code"
  elif dir_exists "$HOME/.vscode-server/bin"; then
    # VS Code Server (for remote/WSL connections)
    if is_wsl; then
      # WSL detected - get distro name
      local wsl_distro="${WSL_DISTRO_NAME:-}"
      if [[ -z "$wsl_distro" ]]; then
        wsl_distro=$(grep -oP '(?<=^NAME=").+(?=")' /etc/os-release 2>/dev/null || echo "Ubuntu")
      fi

      # Prefer Windows code with --remote flag (same as installation)
      if [[ -f "/mnt/c/Program Files/Microsoft VS Code/bin/code" ]] && [[ -n "${WSL_INTEROP:-}" ]]; then
        code_cmd="/mnt/c/Program Files/Microsoft VS Code/bin/code"
        remote_flag="--remote wsl+${wsl_distro}"
      else
        # Fallback to vscode-server CLI
        code_cmd=$(find "$HOME/.vscode-server/bin/" -path "*/bin/remote-cli/code" 2>/dev/null | head -1)
      fi
    else
      # Not WSL, just use vscode-server CLI
      code_cmd=$(find "$HOME/.vscode-server/bin/" -path "*/bin/remote-cli/code" 2>/dev/null | head -1)
    fi
  elif [[ -f "/mnt/c/Program Files/Microsoft VS Code/bin/code" ]]; then
    # Windows VSCode (for WSL without vscode-server yet)
    code_cmd="/mnt/c/Program Files/Microsoft VS Code/bin/code"
  fi

  # Get expected extensions from vscode-extensions.yaml
  local extensions_file="$DEVBASE_CONFIG/vscode-extensions.yaml"
  if ! file_exists "$extensions_file"; then
    extensions_file="${DEVBASE_ROOT:-$(pwd)}/dot/.config/devbase/vscode-extensions.yaml"
  fi

  if ! file_exists "$extensions_file"; then
    printf "  %b✗%b vscode-extensions.yaml not found\n" "${RED}" "${NC}"
    return
  fi

  # Get installed extensions if VS Code is available
  local installed_extensions=""
  local extensions_found_via_fallback=false

  if [[ -n "$code_cmd" ]]; then
    if [[ -n "$remote_flag" ]]; then
      installed_extensions=$("$code_cmd" "$remote_flag" --list-extensions 2>/dev/null || echo "")
    else
      installed_extensions=$("$code_cmd" --list-extensions 2>/dev/null || echo "")
    fi
  fi

  # Fallback 1: Read from vscode-server extensions.json if code command failed
  if [[ -z "$installed_extensions" ]] && [[ -f "$HOME/.vscode-server/extensions/extensions.json" ]]; then
    if command -v jq &>/dev/null; then
      installed_extensions=$(jq -r '.[].identifier.id' "$HOME/.vscode-server/extensions/extensions.json" 2>/dev/null || echo "")
      [[ -n "$installed_extensions" ]] && extensions_found_via_fallback=true
    fi
  fi

  # Fallback 2: List extension directories directly from vscode-server (works in su -l sessions where Windows PATH isn't available)
  if [[ -z "$installed_extensions" ]] && [[ -d "$HOME/.vscode-server/extensions" ]]; then
    installed_extensions=$(
      for ext in "$HOME/.vscode-server/extensions"/*; do
        [[ -d "$ext" ]] || continue
        basename "$ext"
      done | grep -v "^extensions.json$" | sed 's/-[0-9].*//' | sort -u
    )
    [[ -n "$installed_extensions" ]] && extensions_found_via_fallback=true
  fi

  # Fallback 3: List extension directories from native VS Code install (~/.vscode/extensions)
  if [[ -z "$installed_extensions" ]] && [[ -d "$HOME/.vscode/extensions" ]]; then
    installed_extensions=$(
      for ext in "$HOME/.vscode/extensions"/*; do
        [[ -d "$ext" ]] || continue
        basename "$ext"
      done | grep -v "^extensions.json$" | sed 's/-[0-9].*//' | sort -u
    )
    [[ -n "$installed_extensions" ]] && extensions_found_via_fallback=true
  fi

  local ext_installed=0
  local ext_missing=0

  # Collect all extensions first for sorting
  declare -a extensions_list

  # Parse vscode-extensions.yaml for VS Code extensions
  while IFS=: read -r ext_id value_line; do
    # Skip comments and empty lines
    [[ "$ext_id" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$ext_id" ]] && continue

    # Trim leading/trailing whitespace from extension ID
    ext_id=$(echo "$ext_id" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Skip if still empty after trimming
    [[ -z "$ext_id" ]] && continue

    extensions_list+=("$ext_id")
  done <"$extensions_file"

  # Sort extensions alphabetically (case-insensitive)
  local sorted_extensions
  mapfile -t sorted_extensions < <(printf '%s\n' "${extensions_list[@]}" | sort -f)

  # Display sorted extensions
  for ext_id in "${sorted_extensions[@]}"; do
    # Check if installed (only if VS Code is available)
    if [[ -n "$installed_extensions" ]] && echo "$installed_extensions" | grep -qi "^${ext_id}$"; then
      ext_installed=$((ext_installed + 1))
      printf "  %b✓%b %s\n" "${GREEN}" "${NC}" "$ext_id"
    else
      ext_missing=$((ext_missing + 1))
      if [[ -z "$code_cmd" ]] && [[ "$extensions_found_via_fallback" == "false" ]]; then
        # VS Code not found and no fallback worked, show as gray/not checkable
        printf "  %b%s%b %s\n" "${GRAY}" "$INFO" "${NC}" "$ext_id"
      else
        # VS Code found (or extensions dir exists) but extension missing
        printf "  %b✗%b %s\n" "${RED}" "${NC}" "$ext_id"
      fi
    fi
  done

  # Summary line
  printf "\n"
  if [[ -z "$code_cmd" ]] && [[ "$extensions_found_via_fallback" == "false" ]]; then
    printf "  %b→ VS Code not installed (0/%d extensions checkable)%b\n" "${GRAY}" "$ext_missing" "${NC}"
  elif [[ $ext_missing -eq 0 ]]; then
    printf "  %b→ %d/%d extensions installed ✓%b\n" "${GREEN}" "$ext_installed" "$((ext_installed + ext_missing))" "${NC}"
  else
    printf "  %b→ %d/%d extensions installed (%d missing)%b\n" "${YELLOW}" "$ext_installed" "$((ext_installed + ext_missing))" "$ext_missing" "${NC}"
  fi
}

# Check proxy environment
check_proxy_env() {
  print_subheader "Proxy Configuration"
  local proxy_vars=("HTTP_PROXY" "HTTPS_PROXY" "NO_PROXY" "ALL_PROXY")
  local has_proxy=false

  for var in "${proxy_vars[@]}"; do
    if check_env_var "$var" "$MAX_VALUE_LENGTH" true; then
      has_proxy=true
    fi
  done

  if [[ "$has_proxy" == "false" ]]; then
    printf "  %b○%b No proxy configured\n" "${GRAY}" "${NC}"
  fi
}

# Check development language environment
check_dev_language_env() {
  print_subheader "Development Language Settings"

  check_env_var "JAVA_HOME" "$MAX_VALUE_LENGTH" || true

  # Special handling for JAVA_TOOL_OPTIONS
  [[ -z "${JAVA_TOOL_OPTIONS:-}" ]] && {
    if ! check_env_var "GRADLE_OPTS" "$MAX_VALUE_LENGTH"; then
      [[ -n "${HTTP_PROXY:-}" ]] &&
        printf "  %b%s%b GRADLE_OPTS not set (~/.gradle/gradle.properties)\n" "${YELLOW}" "$WARN" "${NC}"
    fi
    check_env_var "MAVEN_OPTS" "$MAX_VALUE_LENGTH" || true
    check_env_var "NPM_CONFIG_REGISTRY" "$MAX_VALUE_LENGTH" || true
    check_env_var "CYPRESS_DOWNLOAD_MIRROR" "$MAX_VALUE_LENGTH" || true

    return 0
  }

  local java_opts="${JAVA_TOOL_OPTIONS}"
  # Mask password in proxy URLs (http://user:pass@host -> http://***:***@host)
  java_opts=$(echo "$java_opts" | sed 's/:[^@]*@/:****@/')

  # Check if needs wrapping
  if [[ ${#java_opts} -gt 80 ]] && [[ "$java_opts" == *"-Dhttps.proxyHost"* ]]; then
    local part1="${java_opts%% -Dhttps.proxyHost=*}"
    local part2="-Dhttps.proxyHost=${java_opts#*-Dhttps.proxyHost=}"
    printf "  %b%s%b JAVA_TOOL_OPTIONS = %s\n" "${GREEN}" "$CHECK" "${NC}" "$part1"
    printf "      %s\n" "$part2"
  else
    printf "  %b%s%b JAVA_TOOL_OPTIONS = %s\n" "${GREEN}" "$CHECK" "${NC}" "$java_opts"
  fi

  if ! check_env_var "GRADLE_OPTS" "$MAX_VALUE_LENGTH"; then
    [[ -n "${HTTP_PROXY:-}" ]] &&
      printf "  %b%s%b GRADLE_OPTS not set (~/.gradle/gradle.properties)\n" "${YELLOW}" "$WARN" "${NC}"
  fi
  check_env_var "MAVEN_OPTS" "$MAX_VALUE_LENGTH" || true
  check_env_var "NPM_CONFIG_REGISTRY" "$MAX_VALUE_LENGTH" || true
  check_env_var "CYPRESS_DOWNLOAD_MIRROR" "$MAX_VALUE_LENGTH" || true
}

# Check XDG environment
check_xdg_env() {
  print_subheader "XDG Base Directory Specification"

  check_env_var "XDG_CONFIG_HOME" "$MAX_VALUE_LENGTH" || true
  check_env_var "XDG_DATA_HOME" "$MAX_VALUE_LENGTH" || true
  check_env_var "XDG_CACHE_HOME" "$MAX_VALUE_LENGTH" || true
}

# Check DevBase-specific environment
check_devbase_env() {
  # Skip DevBase settings - not needed

  # Misc environment variables
  print_subheader "Misc"
  local tool_vars=("TERM" "DOCKER_HOST" "GPG_TTY" "SSH_AUTH_SOCK" "STARSHIP_CONFIG" "BAT_THEME" "EDITOR" "VISUAL")
  for var in "${tool_vars[@]}"; do
    check_env_var "$var" "$MAX_VALUE_LENGTH" || true
  done
}

# Check PATH entries
check_path_entries() {
  print_subheader "PATH additions"

  # Only check paths that DevBase actively manages and creates
  local devbase_paths=(
    "$HOME/.local/bin" # Created and added by DevBase for user binaries
  )

  for check_path in "${devbase_paths[@]}"; do
    local display_path=$(normalize_path "$check_path")

    # Early check if in PATH
    [[ ":$PATH:" == *":${check_path}:"* ]] && {
      printf "  %b%s%b %s\n" "${GREEN}" "$CHECK" "${NC}" "$display_path"
      continue
    }

    # Not in PATH - check if directory exists
    dir_exists "$check_path" && printf "  %b%s%b %s (exists but not in PATH)\n" "${YELLOW}" "$WARN" "${NC}" "$display_path" ||
      printf "  %b%s%b %s (directory missing)\n" "${RED}" "$CROSS" "${NC}" "$display_path"
  done
}

check_environment() {
  print_header "10. Environment Variables"

  check_proxy_env
  check_dev_language_env
  check_xdg_env
  check_devbase_env
  check_path_entries
}

check_common_issues() {
  print_header "11. Common Post-Install Issues"

  # Check shell configuration
  if command -v fish &>/dev/null; then
    print_check "pass" "Shell: Fish installed"
  else
    print_check "fail" "Shell: Fish not installed"
  fi

  # Check if .bashrc has fish exec
  check_file_content "$HOME/.bashrc" "Launch Fish for interactive sessions (added by devbase)" \
    "Auto-launch Fish: Configured" "Auto-launch Fish: Not configured" "warn"

  # Check locale
  local current_locale=$(locale | grep "^LANG=" | cut -d= -f2)
  [[ -z "$current_locale" ]] && {
    print_check "warn" "Locale not set"
    return 0
  }

  if echo "$current_locale" | grep -q "UTF-8"; then
    print_check "pass" "Locale: $current_locale"
  else
    print_check "warn" "Non-UTF-8 locale: $current_locale"
  fi
}

# Check for WSL-specific DevBase configuration
check_wsl_config() {
  # WSL-specific section removed - all checks are covered in other sections:
  # - Wayland socket service: checked in section 4 (Systemd Services)
  # - VS Code extensions: checked in section 10 (VS Code Extensions)
  # DevBase doesn't configure other WSL internals - those are managed by WSL itself
  return 0
}

# Main summary
print_summary() {
  print_header "Installation Verification Summary"

  local total_non_info=$((PASSED_CHECKS + FAILED_CHECKS + WARNING_CHECKS))
  local pass_rate=0
  if [[ $total_non_info -gt 0 ]]; then
    pass_rate=$((PASSED_CHECKS * 100 / total_non_info))
  fi

  printf "\n"
  printf "  %bPassed:%b        %d\n" "${GREEN}" "${NC}" "$PASSED_CHECKS"
  if [[ $WARNING_CHECKS -gt 0 ]]; then
    printf "  %bWarnings:%b      %d\n" "${YELLOW}" "${NC}" "$WARNING_CHECKS"
  fi
  if [[ $FAILED_CHECKS -gt 0 ]]; then
    printf "  %bFailed:%b        %d\n" "${RED}" "${NC}" "$FAILED_CHECKS"
  fi
  printf "  Pass Rate:      %d%%\n" "$pass_rate"

  # List warnings if any
  if [[ ${#WARNING_MESSAGES[@]} -gt 0 ]]; then
    printf "\n  %bWarnings:%b\n" "${YELLOW}" "${NC}"
    for msg in "${WARNING_MESSAGES[@]}"; do
      printf "    %b‼%b %s\n" "${YELLOW}" "${NC}" "$msg"
    done
  fi

  # List failures if any
  if [[ ${#FAILED_MESSAGES[@]} -gt 0 ]]; then
    printf "\n  %bFailures:%b\n" "${RED}" "${NC}"
    for msg in "${FAILED_MESSAGES[@]}"; do
      printf "    %b✗%b %s\n" "${RED}" "${NC}" "$msg"
    done
  fi

  printf "\n"
  if [[ $pass_rate -eq 100 ]]; then
    printf "%b✅ Installation complete - all checks passed!%b\n" "${GREEN}" "${NC}"
  elif [[ $pass_rate -ge 90 ]]; then
    printf "%b✓ Installation successful with minor issues%b\n" "${GREEN}" "${NC}"
  elif [[ $pass_rate -ge 75 ]]; then
    printf "%b⚠ Installation mostly complete (%d%% pass rate)%b\n" "${YELLOW}" "$pass_rate" "${NC}"
  elif [[ $pass_rate -ge 50 ]]; then
    printf "%b⚠ Installation partially complete (%d%% pass rate)%b\n" "${YELLOW}" "$pass_rate" "${NC}"
  else
    printf "%b✗ Installation incomplete (%d%% pass rate)%b\n" "${RED}" "$pass_rate" "${NC}"
    printf "\nNext steps:\n"
    printf "  1. Ensure mise is activated: eval \"\$(mise activate bash)\"\n"
    printf "  2. Install missing tools: mise install\n"
    printf "  3. Restart your shell or source ~/.bashrc\n"
  fi
}

# Quick check mode

# Check security-sensitive permissions for DevBase-managed items
check_security() {
  print_header "12. Security & Permissions"

  # Check directory permissions
  # print_subheader "DevBase Directory Permissions"

  for dir in "${!DIR_PERMISSIONS[@]}"; do
    if dir_exists "$dir"; then
      check_permissions "$dir" "${DIR_PERMISSIONS[$dir]}" "dir"
    fi
  done

  # Check SSH file permissions
  # print_subheader "DevBase SSH File Permissions"

  for file in "${!FILE_PERMISSIONS[@]}"; do
    if file_exists "$file"; then
      check_permissions "$file" "${FILE_PERMISSIONS[$file]}" "file"
    fi
  done

  # Service file permissions are checked in systemd section, not here
}

# Proxy check functions now in verify-base-lib.sh

# Organization-specific verification (sections 13-14) moved to custom verification
# Custom verification script location: devbase-custom-config/verification/verify-custom.sh

# Check Secure Boot status (extra security check, not counted in statistics)
check_secure_boot_status() {
  # Skip on WSL
  if [[ -f /proc/sys/kernel/osrelease ]] && grep -qi "microsoft\|wsl" /proc/sys/kernel/osrelease 2>/dev/null; then
    return 0
  fi

  # Skip if mokutil not available
  if ! command -v mokutil &>/dev/null; then
    return 0
  fi

  printf "\n"
  print_header "Extra Security Check: Secure Boot"

  local sb_state
  sb_state=$(mokutil --sb-state 2>/dev/null || echo "unknown")

  if echo "$sb_state" | grep -qi "SecureBoot enabled"; then
    printf "  %b%s%b Secure Boot is enabled\n" "${GREEN}" "$CHECK" "${NC}"
  else
    printf "  %b%s%b WARNING: Secure Boot is DISABLED\n" "${YELLOW}" "$WARN" "${NC}"
    printf "  %b   Action required: Enable Secure Boot in UEFI/BIOS settings%b\n" "${YELLOW}" "${NC}"
    printf "  %b   This is a security best practice for production systems%b\n" "${DIM}" "${NC}"
  fi
}

find_custom_verification() {
  local candidates=(
    "../devbase-custom-config/verification/verify-custom.sh"
    "./devbase-custom-config/verification/verify-custom.sh"
    "${DEVBASE_CUSTOM_DIR:-}/verification/verify-custom.sh"
  )

  for path in "${candidates[@]}"; do
    if [[ -f "$path" ]] && [[ -x "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  return 1
}

run_custom_verification() {
  local custom_verify

  if custom_verify=$(find_custom_verification); then
    printf "\n"
    print_header "Organization Custom Verification"
    printf "  %b→ Running: %s%b\n" "${DIM}" "$custom_verify" "${NC}"
    printf "\n"

    # shellcheck source=/dev/null
    if source "$custom_verify"; then
      return 0
    else
      print_check "warn" "Custom verification script failed"
      return 1
    fi
  else
    print_check "info" "No custom verification script found"
    printf "  %b→ For organization-specific checks, create:%b\n" "${DIM}" "${NC}"
    printf "  %b   devbase-custom-config/verification/verify-custom.sh%b\n" "${DIM}" "${NC}"
    return 0
  fi
}

main() {
  printf "%b%s%b\n" "${BOLD}${CYAN}" "╔════════════════════════════════════════════╗" "${NC}"
  printf "%b%s%b\n" "${BOLD}${CYAN}" "    DevBase Installation Verification         " "${NC}"
  printf "%b%s%b\n" "${BOLD}${CYAN}" "    $(date '+%Y-%m-%d %H:%M:%S')              " "${NC}"
  printf "%b%s%b\n" "${BOLD}${CYAN}" "╚════════════════════════════════════════════╝" "${NC}"

  # Run all base checks - never stop early
  check_mise_activation
  check_user_directories
  check_config_files
  check_systemd_services
  check_git_config
  check_ssh_config
  check_shell_integrations
  check_installed_tools
  check_vscode_extensions
  check_environment
  check_common_issues
  check_wsl_config
  check_security

  # Run organization-specific verification if available
  run_custom_verification

  # Extra security checks (not counted in pass/fail percentage)
  check_secure_boot_status

  print_summary

  # Return exit code based on check results
  # In CI mode (NON_INTERACTIVE=true), treat warnings as failures
  if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
    if [[ $FAILED_CHECKS -gt 0 ]] || [[ $WARNING_CHECKS -gt 0 ]]; then
      return 1
    fi
  else
    # Interactive mode: only fail on actual failures
    if [[ $FAILED_CHECKS -gt 0 ]]; then
      return 1
    fi
  fi
  return 0
}

# Just run main directly
main "$@"
exit $?
