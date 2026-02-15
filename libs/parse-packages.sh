#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Parse packages.yaml and provide package lists for installers
# Requires: yq
#
# Package structure in packages.yaml:
#   common:  - packages with same name on all distros
#   apt:     - Ubuntu/Debian specific packages
#   dnf:     - Fedora/RHEL specific packages (experimental)

# Re-source guard: skip top-level init if already loaded
if [[ -n "${_DEVBASE_PARSE_PACKAGES_SOURCED:-}" ]]; then
  return 0
fi
_DEVBASE_PARSE_PACKAGES_SOURCED=1

# CRITICAL: yq is required for YAML parsing - fail fast if not available
if ! command -v yq &>/dev/null; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  echo "ERROR: yq is required but not installed!" >&2
  echo "" >&2
  echo "yq is needed to parse packages.yaml configuration." >&2
  echo "This usually means mise failed to bootstrap yq." >&2
  echo "" >&2
  echo "To fix: Install yq manually or check mise installation:" >&2
  echo "  mise install aqua:mikefarah/yq" >&2
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
  _DEVBASE_PARSE_PACKAGES_SOURCED=""
  return 1
fi

# Global: Path to packages.yaml (set by caller or default)
PACKAGES_YAML="${PACKAGES_YAML:-${DEVBASE_DOT}/.config/devbase/packages.yaml}"
PACKAGES_CUSTOM_YAML="${PACKAGES_CUSTOM_YAML:-}"

# Selected packs (set by caller, space-separated)
SELECTED_PACKS="${SELECTED_PACKS:-${DEVBASE_DEFAULT_PACKS:-java node python go ruby}}"

# Brief: Set up package YAML environment (shared by all package loaders)
# Params: None
# Uses: DEVBASE_DOT, DEVBASE_DEFAULT_PACKS, DEVBASE_SELECTED_PACKS, _DEVBASE_CUSTOM_PACKAGES (globals)
# Returns: 0 on success, 1 if packages.yaml not found
# Side-effects: Exports PACKAGES_YAML, SELECTED_PACKS, PACKAGES_CUSTOM_YAML; resets merge cache
_setup_package_yaml_env() {
  require_env DEVBASE_DOT DEVBASE_DEFAULT_PACKS || return 1
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export SELECTED_PACKS="${DEVBASE_SELECTED_PACKS:-${DEVBASE_DEFAULT_PACKS:-java node python go ruby}}"

  if [[ -n "${_DEVBASE_CUSTOM_PACKAGES:-}" ]] && [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml" ]]; then
    export PACKAGES_CUSTOM_YAML="${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml"
  fi

  if [[ ! -f "$PACKAGES_YAML" ]]; then
    show_progress error "Package configuration not found: $PACKAGES_YAML"
    return 1
  fi

  # Reset merge cache so new env is picked up
  _MERGED_YAML=""
  return 0
}

# Cache for merged packages (avoids re-reading yaml repeatedly)
_MERGED_YAML=""

# Detected package manager (cached, can be pre-set by tests)
_PARSE_PKG_MANAGER="${_PARSE_PKG_MANAGER:-}"

# Brief: Get merged packages.yaml content (base + custom if exists)
# Returns: Merged YAML to stdout (cached after first call)
_get_merged_packages() {
  if [[ -n "$_MERGED_YAML" ]]; then
    echo "$_MERGED_YAML"
    return
  fi

  if [[ -n "$PACKAGES_CUSTOM_YAML" && -f "$PACKAGES_CUSTOM_YAML" ]]; then
    _MERGED_YAML=$(yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$PACKAGES_YAML" "$PACKAGES_CUSTOM_YAML")
  else
    _MERGED_YAML=$(cat "$PACKAGES_YAML")
  fi
  echo "$_MERGED_YAML"
}

# Brief: Get the package manager for current distro
# Returns: apt, dnf
_get_pkg_manager() {
  if [[ -n "$_PARSE_PKG_MANAGER" ]]; then
    echo "$_PARSE_PKG_MANAGER"
    return
  fi

  # Try to use distro.sh if available
  if declare -f get_pkg_manager &>/dev/null; then
    _PARSE_PKG_MANAGER=$(get_pkg_manager)
  elif [[ -f "${DEVBASE_ROOT:-}/libs/distro.sh" ]]; then
    # shellcheck source=distro.sh
    source "${DEVBASE_ROOT}/libs/distro.sh"
    _PARSE_PKG_MANAGER=$(get_pkg_manager)
  else
    # Fallback: detect by available command
    if command -v apt &>/dev/null; then
      _PARSE_PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
      _PARSE_PKG_MANAGER="dnf"
    else
      _PARSE_PKG_MANAGER="apt" # Default fallback
    fi
  fi

  echo "$_PARSE_PKG_MANAGER"
}

# Brief: Check if package should be skipped based on tags
# Params: $1 = tags string (e.g., '["@skip-wsl"]' or '')
# Returns: 0 if should skip, 1 if should install
_should_skip() {
  local tags="$1"
  [[ -z "$tags" || "$tags" == "null" ]] && return 1
  [[ "$tags" == *"@skip-wsl"* ]] && is_wsl 2>/dev/null && return 0
  return 1
}

# Brief: Process packages from a yq path for system packages (apt/dnf)
# Params: $1=yaml content, $2=yq path (e.g., ".core.apt" or ".packs.java.common")
_process_system_packages() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    local tags
    tags=$(echo "$yaml" | yq -r "${path}[\"$pkg\"].tags // \"\"")
    _should_skip "$tags" || echo "$pkg"
  done
}

# Brief: Process packages from a yq path for apt type (backward compat alias)
# Params: $1=yaml content, $2=yq path (e.g., ".core.apt" or ".packs.java.apt")
_process_apt() {
  _process_system_packages "$@"
}

# Brief: Process packages from a yq path for snap type
# Params: $1=yaml content, $2=yq path
_process_snap() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    local tags options
    tags=$(echo "$yaml" | yq -r "${path}[\"$pkg\"].tags // \"\"")
    options=$(echo "$yaml" | yq -r "${path}[\"$pkg\"].options // \"\"")
    _should_skip "$tags" || echo "${pkg}|${options}"
  done
}

# Brief: Process packages from a yq path for mise type
# Params: $1=yaml content, $2=yq path
_process_mise() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r tool; do
    [[ -z "$tool" ]] && continue
    local backend version tags tool_key
    backend=$(echo "$yaml" | yq -r "${path}[\"$tool\"].backend // \"\"")
    version=$(echo "$yaml" | yq -r "${path}[\"$tool\"].version // \"\"")
    tags=$(echo "$yaml" | yq -r "${path}[\"$tool\"].tags // \"\"")

    _should_skip "$tags" && continue

    # Build tool key for mise config
    if [[ -n "$backend" && "$backend" != "null" ]]; then
      tool_key="$backend"
    else
      tool_key="$tool"
    fi
    echo "${tool_key}|${version}"
  done
}

# Brief: Process packages from a yq path for custom type
# Params: $1=yaml content, $2=yq path
_process_custom() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r tool; do
    [[ -z "$tool" ]] && continue
    local version installer tags
    version=$(echo "$yaml" | yq -r "${path}[\"$tool\"].version // \"\"")
    installer=$(echo "$yaml" | yq -r "${path}[\"$tool\"].installer // \"\"")
    tags=$(echo "$yaml" | yq -r "${path}[\"$tool\"].tags // \"\"")
    _should_skip "$tags" && continue
    echo "${tool}|${version}|${installer}|${tags}"
  done
}

# Brief: Process packages from a yq path for vscode type
# Params: $1=yaml content, $2=yq path
_process_vscode() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r ext; do
    [[ -z "$ext" ]] && continue
    local version tags
    version=$(echo "$yaml" | yq -r "${path}[\"$ext\"].version // \"\"")
    tags=$(echo "$yaml" | yq -r "${path}[\"$ext\"].tags // \"\"")
    _should_skip "$tags" && continue
    echo "${ext}|${version}|${tags}"
  done
}

# Brief: Get system packages from core + selected packs for current distro
# Output: Package names, one per line
# Note: Reads both 'common' section and distro-specific section (apt/dnf)
get_system_packages() {
  local yaml pkg_mgr
  yaml=$(_get_merged_packages)
  pkg_mgr=$(_get_pkg_manager)

  # Core packages: common + distro-specific
  _process_system_packages "$yaml" ".core.common"
  _process_system_packages "$yaml" ".core.${pkg_mgr}"

  # Pack packages: common + distro-specific
  for pack in $SELECTED_PACKS; do
    _process_system_packages "$yaml" ".packs.${pack}.common"
    _process_system_packages "$yaml" ".packs.${pack}.${pkg_mgr}"
  done
}

# Brief: Get apt packages from core + selected packs (backward compatibility)
# Output: Package names, one per line
# Deprecated: Use get_system_packages() instead
get_apt_packages() {
  local yaml
  yaml=$(_get_merged_packages)

  # Old structure: .core.apt directly (no common section)
  # New structure: .core.common + .core.apt
  # Support both for backward compatibility
  _process_system_packages "$yaml" ".core.common"
  _process_system_packages "$yaml" ".core.apt"
  for pack in $SELECTED_PACKS; do
    _process_system_packages "$yaml" ".packs.${pack}.common"
    _process_system_packages "$yaml" ".packs.${pack}.apt"
  done
}

# Brief: Process packages from a yq path for flatpak type
# Params: $1=yaml content, $2=yq path
_process_flatpak() {
  local yaml="$1" path="$2"
  echo "$yaml" | yq -r "$path // {} | keys | .[]" 2>/dev/null | while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    local tags remote
    tags=$(echo "$yaml" | yq -r "${path}[\"$pkg\"].tags // \"\"")
    remote=$(echo "$yaml" | yq -r "${path}[\"$pkg\"].remote // \"flathub\"")
    _should_skip "$tags" || echo "${pkg}|${remote}"
  done
}

# Brief: Get snap packages from core + selected packs
# Output: Lines of "package_name|options"
get_snap_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_snap "$yaml" ".core.snap"
  for pack in $SELECTED_PACKS; do
    _process_snap "$yaml" ".packs.${pack}.snap"
  done
}

# Brief: Get flatpak packages from core + selected packs
# Output: Lines of "app_id|remote"
get_flatpak_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_flatpak "$yaml" ".core.flatpak"
  for pack in $SELECTED_PACKS; do
    _process_flatpak "$yaml" ".packs.${pack}.flatpak"
  done
}

# Brief: Get app store packages for current distro (snap or flatpak)
# Output: Lines of "package|options" for snap or "app_id|remote" for flatpak
get_app_store_packages() {
  local app_store
  if declare -f get_app_store &>/dev/null; then
    app_store=$(get_app_store)
  elif [[ -f "${DEVBASE_ROOT:-}/libs/distro.sh" ]]; then
    # shellcheck source=distro.sh
    source "${DEVBASE_ROOT}/libs/distro.sh"
    app_store=$(get_app_store)
  else
    # Default to snap for Ubuntu
    app_store="snap"
  fi

  case "$app_store" in
  snap)
    get_snap_packages
    ;;
  flatpak)
    get_flatpak_packages
    ;;
  *)
    # No app store available (e.g., WSL)
    return 0
    ;;
  esac
}

# Brief: Get mise tools from core + selected packs
# Output: Lines of "tool_key|version"
get_mise_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_mise "$yaml" ".core.mise"
  for pack in $SELECTED_PACKS; do
    _process_mise "$yaml" ".packs.${pack}.mise"
  done
}

# Brief: Get custom tools from core + selected packs
# Output: Lines of "tool|version|installer|tags"
get_custom_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_custom "$yaml" ".core.custom"
  for pack in $SELECTED_PACKS; do
    _process_custom "$yaml" ".packs.${pack}.custom"
  done
}

# Brief: Get vscode extensions from core + selected packs
# Output: Lines of "extension_id|version|tags"
get_vscode_packages() {
  local yaml
  yaml=$(_get_merged_packages)
  _process_vscode "$yaml" ".core.vscode"
  for pack in $SELECTED_PACKS; do
    _process_vscode "$yaml" ".packs.${pack}.vscode"
  done
}

# Brief: Get available packs with descriptions
# Output: Lines of "pack_name|description"
get_available_packs() {
  local yaml
  yaml=$(_get_merged_packages)
  echo "$yaml" | yq -r '.packs | keys | .[]' | while read -r pack; do
    local desc
    desc=$(echo "$yaml" | yq -r ".packs.${pack}.description // \"\"")
    echo "${pack}|${desc}"
  done
}

# Brief: Get pack contents for display (primary tools only, with counts for secondary items)
# Params: $1 = pack name, $2 = show_vscode ("true" to show VS Code extensions, default "true")
# Output: Human-friendly list of main tools with summary of extras
get_pack_contents() {
  local pack="$1"
  local show_vscode="${2:-true}"
  local yaml pkg_mgr
  yaml=$(_get_merged_packages)
  pkg_mgr=$(_get_pkg_manager)

  # Get mise tool names (primary tools users care about)
  echo "$yaml" | yq -r ".packs.${pack}.mise // {} | keys | .[]" 2>/dev/null

  # Get custom installer names (GUI tools like IntelliJ, DBeaver)
  echo "$yaml" | yq -r ".packs.${pack}.custom // {} | keys | .[]" 2>/dev/null

  # Get vscode extension names with label (only if user chose to install extensions)
  if [[ "$show_vscode" == "true" ]]; then
    local ext
    while IFS= read -r ext; do
      [[ -n "$ext" ]] && echo "$ext (VS Code)"
    done < <(echo "$yaml" | yq -r ".packs.${pack}.vscode // {} | keys | .[]" 2>/dev/null)
  fi

  # Count system packages (common + distro-specific - build dependencies, less interesting to users)
  local common_count distro_count total_count
  common_count=$(echo "$yaml" | yq -r ".packs.${pack}.common // {} | keys | length" 2>/dev/null)
  distro_count=$(echo "$yaml" | yq -r ".packs.${pack}.${pkg_mgr} // {} | keys | length" 2>/dev/null)
  total_count=$((common_count + distro_count))
  [[ "$total_count" -gt 0 ]] && echo "+ ${total_count} system packages"

  return 0
}

# Brief: Get version of a specific tool from packages.yaml
# Params: $1 = tool name (e.g., "mise", "node", "vscode")
# Output: Version string
get_tool_version() {
  local tool="$1"
  local yaml version
  yaml=$(_get_merged_packages)

  # Check core.custom, core.mise, then packs
  for path in ".core.custom" ".core.mise"; do
    version=$(echo "$yaml" | yq -r "${path}[\"$tool\"].version // \"\"")
    [[ -n "$version" && "$version" != "null" ]] && echo "$version" && return
  done

  for pack in $SELECTED_PACKS; do
    for type in "custom" "mise"; do
      version=$(echo "$yaml" | yq -r ".packs.${pack}.${type}[\"$tool\"].version // \"\"")
      [[ -n "$version" && "$version" != "null" ]] && echo "$version" && return
    done
  done
}

# Brief: Get core language runtimes from selected packs
# Output: Space-separated list of runtime names
get_core_runtimes() {
  local runtimes=""
  for pack in $SELECTED_PACKS; do
    case "$pack" in
    java) runtimes+=" java maven gradle" ;;
    node) runtimes+=" node" ;;
    python) runtimes+=" python" ;;
    go) runtimes+=" go" ;;
    ruby) runtimes+=" ruby" ;;
    rust) runtimes+=" rust" ;;
    esac
  done
  echo "${runtimes# }"
}

# Brief: Generate mise config.toml from packages.yaml
# Params: $1 = output file path
generate_mise_config() {
  local output_file="$1"

  local template_config="${DEVBASE_DOT}/.config/mise/config.toml"
  if [[ -f "$template_config" ]]; then
    awk '
      { print }
      /^\[tools\]$/ { exit }
    ' "$template_config" >"$output_file"
  else
    cat >"$output_file" <<'EOF'
# Auto-generated from packages.yaml - DO NOT EDIT DIRECTLY
# To modify tools, edit packages.yaml and re-run setup

[settings]
experimental = true
legacy_version_file = false
asdf_compat = false
jobs = 6
yes = true
http_timeout = "90s"

[env]
HTTP_PROXY = "{{ get_env(name='HTTP_PROXY', default='') }}"
HTTPS_PROXY = "{{ get_env(name='HTTPS_PROXY', default='') }}"
NO_PROXY = "{{ get_env(name='NO_PROXY', default='') }}"
http_proxy = "{{ get_env(name='http_proxy', default='') }}"
https_proxy = "{{ get_env(name='https_proxy', default='') }}"
no_proxy = "{{ get_env(name='no_proxy', default='') }}"
PIP_INDEX_URL = "{{ get_env(name='PIP_INDEX_URL', default='') }}"
NPM_CONFIG_REGISTRY = "{{ get_env(name='NPM_CONFIG_REGISTRY', default='') }}"
RUBY_CONFIGURE_OPTS = "--with-openssl-dir=/usr"
EOF
  fi

  printf "\n[tools]\n" >>"$output_file"
  get_mise_packages | while IFS='|' read -r tool_key version; do
    [[ -z "$tool_key" || -z "$version" ]] && continue
    if [[ "$tool_key" == *:* || "$tool_key" == *[* ]]; then
      echo "\"$tool_key\" = \"$version\""
    else
      echo "$tool_key = \"$version\""
    fi
  done >>"$output_file"
}
