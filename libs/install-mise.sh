#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

declare -gA TOOL_VERSIONS

# Brief: Load tool versions from custom-tools.yaml into TOOL_VERSIONS array
# Params: None
# Uses: _VERSIONS_FILE (global), modifies TOOL_VERSIONS (global)
# Returns: 0 on success, calls die() on failure
# Side-effects: Populates TOOL_VERSIONS associative array
load_all_versions() {
  show_progress info "Loading tool versions..."

  validate_file_exists "${_VERSIONS_FILE}" "Versions file" || die "Versions file not found: ${_VERSIONS_FILE}"
  [[ ! -r "${_VERSIONS_FILE}" ]] && die "Versions file not readable: ${_VERSIONS_FILE} (check permissions)"

  while IFS= read -r line; do
    [[ -n "$line" && "$line" != \#* ]] || continue

    if [[ "$line" =~ ^([^:]+):[[:space:]]*([^[:space:]#]+) ]]; then
      local tool="${BASH_REMATCH[1]// /}"
      local version="${BASH_REMATCH[2]}"

      local version
      version=$(printf "%s" "$version" | tr -d '"' | tr -d "'")
      [[ -n "$version" ]] || continue

      TOOL_VERSIONS[$tool]=$version
    fi
  done <"${_VERSIONS_FILE}"

  if [[ ${#TOOL_VERSIONS[@]} -eq 0 ]]; then
    die "No valid tool versions loaded from ${_VERSIONS_FILE}"
  fi

  validate_critical_versions

  show_progress success "Loaded ${#TOOL_VERSIONS[@]} tool versions"
  return 0
}

# Brief: Validate that critical tools have version numbers loaded
# Params: None
# Uses: TOOL_VERSIONS (global)
# Returns: 0 always (warnings only, non-fatal)
# Side-effects: Displays warnings if versions missing
# Note: nodejs, python, java, golang are managed directly in mise/config.toml, not custom-tools.yaml
validate_critical_versions() {
  # Check for mise itself (the only critical tool in custom-tools.yaml)
  if [[ -z "${TOOL_VERSIONS[mise]:-}" ]]; then
    show_progress warning "mise version not found in custom-tools.yaml"
    return 0
  fi

  # All other critical tools (node, python, java) are in mise/config.toml
  return 0
}

# Brief: Update mise config.toml with versions from TOOL_VERSIONS
# Params: None
# Uses: TOOL_VERSIONS, DEVBASE_DOT, _DEVBASE_TEMP (globals)
# Returns: 0 always
# Side-effects: Modifies mise config.toml in dotfiles
sync_mise_config_versions() {
  validate_var_set "DEVBASE_DOT" || return 1
  # shellcheck disable=SC2153 # DEVBASE_DOT validated above, exported in setup.sh
  local mise_config_src="${DEVBASE_DOT}/.config/mise/config.toml"
  [[ ! -f "$mise_config_src" ]] && return 0

  local node_version="${TOOL_VERSIONS[nodejs]:-}"
  local golang_version="${TOOL_VERSIONS[golang]:-}"
  local python_version="${TOOL_VERSIONS[python]:-}"
  local java_version="${TOOL_VERSIONS[java_jdk]:-}"
  local maven_version="${TOOL_VERSIONS[maven]:-}"
  local gradle_version="${TOOL_VERSIONS[gradle]:-}"

  local temp_config="${_DEVBASE_TEMP}/mise_config_temp.toml"
  cp "$mise_config_src" "$temp_config"

  if [[ -n "$node_version" ]]; then
    sed -i "s/^node = .*/node = \"${node_version}\"/" "$temp_config"
  fi
  if [[ -n "$golang_version" ]]; then
    sed -i "s/^go = .*/go = \"${golang_version}\"/" "$temp_config"
  fi
  if [[ -n "$python_version" ]]; then
    sed -i "s/^python = .*/python = \"${python_version}\"/" "$temp_config"
  fi
  if [[ -n "$java_version" ]]; then
    sed -i "s/^java = .*/java = \"${java_version}\"/" "$temp_config"
  fi
  if [[ -n "$maven_version" ]]; then
    sed -i "s/^maven = .*/maven = \"${maven_version}\"/" "$temp_config"
  fi
  if [[ -n "$gradle_version" ]]; then
    sed -i "s/^gradle = .*/gradle = \"${gradle_version}\"/" "$temp_config"
  fi

  cp "$temp_config" "$mise_config_src"

  return 0
}

# Brief: Verify mise binary checksum against official release checksums
# Params: None
# Uses: XDG_BIN_HOME, DEVBASE_DOT, _DEVBASE_TEMP, retry_command (globals/functions)
# Returns: 0 if valid or skipped, 1 if mise not found or checksum mismatch
# Side-effects: Downloads SHASUMS256.txt, computes sha256sum
verify_mise_checksum() {
  local mise_bin="${XDG_BIN_HOME}/mise"

  if [[ ! -f "$mise_bin" ]]; then
    return 1
  fi

  local arch
  arch="$(uname -m)"

  if [[ "$arch" != "x86_64" ]]; then
    echo "Warning: Checksum verification only supported on x86_64, skipping" >&2
    return 0
  fi

  local versions_file="${DEVBASE_DOT}/.config/devbase/custom-tools.yaml"
  local version

  if [[ -f "$versions_file" ]]; then
    version=$(grep "^mise:" "$versions_file" | head -1 | awk '{print $2}' | sed 's/#.*//' | tr -d ' ')
  fi

  if [[ -z "$version" ]]; then
    echo "Warning: Could not determine expected mise version from custom-tools.yaml" >&2
    return 0
  fi

  # Strip 'v' prefix if present
  version="${version#v}"

  local checksums_url="https://github.com/jdx/mise/releases/download/v${version}/SHASUMS256.txt"
  local checksums_file="${_DEVBASE_TEMP}/mise-checksums.txt"

  if ! retry_command curl -fsSL "$checksums_url" -o "$checksums_file"; then
    echo "Warning: Could not download checksums for mise v${version}" >&2
    return 0
  fi

  local actual_checksum
  actual_checksum=$(sha256sum "$mise_bin" | cut -d' ' -f1)

  local binary_pattern="mise-v${version}-linux-x64"
  if grep -q "$binary_pattern" "$checksums_file" 2>/dev/null; then
    local expected_checksum
    expected_checksum=$(grep "$binary_pattern" "$checksums_file" | head -1 | cut -d' ' -f1)

    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
      return 0
    else
      echo "Error: Mise binary checksum mismatch!" >&2
      echo "Expected: $expected_checksum" >&2
      echo "Actual:   $actual_checksum" >&2
      return 1
    fi
  else
    echo "Warning: Could not find checksum for $binary_pattern" >&2
    return 0
  fi
}

# Brief: Install mise tool version manager
# Params: None
# Uses: _DEVBASE_TEMP, HOME (globals)
# Returns: 0 on success, calls die() on failure
# Side-effects: Downloads and installs mise, activates it for current shell
install_mise() {
  show_progress info "Installing mise (tool version manager)..."

  local mise_path=""
  if command -v /usr/bin/mise &>/dev/null; then
    mise_path="/usr/bin/mise"
  elif command -v "${XDG_BIN_HOME}/mise" &>/dev/null; then
    mise_path="${XDG_BIN_HOME}/mise"
  elif command_exists mise; then
    mise_path="$(command -v mise)"
  fi

  if [[ -z "$mise_path" ]]; then
    # Install mise to XDG_BIN_HOME
    local mise_installer="${_DEVBASE_TEMP}/mise_installer.sh"

    if ! retry_command download_file "https://mise.run" "$mise_installer"; then
      die "Failed to download Mise installer after retries"
    fi

    if [[ ! -s "$mise_installer" ]] || ! grep -q "mise" "$mise_installer"; then
      die "Downloaded file doesn't appear to be Mise installer"
    fi

    # Get mise version from custom-tools.yaml
    local mise_version=""
    if [[ -n "${TOOL_VERSIONS[mise]:-}" ]]; then
      mise_version="${TOOL_VERSIONS[mise]}"
    else
      # Fallback: read directly from custom-tools.yaml if TOOL_VERSIONS not populated yet
      local versions_file="${DEVBASE_DOT}/.config/devbase/custom-tools.yaml"
      if [[ -f "$versions_file" ]]; then
        mise_version=$(grep "^mise:" "$versions_file" | head -1 | awk '{print $2}' | sed 's/#.*//' | tr -d ' ')
      fi
    fi

    # Set mise version for installer script (if specified)
    if [[ -n "$mise_version" ]]; then
      export MISE_VERSION="$mise_version"
    fi

    bash "$mise_installer" || die "Failed to run Mise installer script"

    # Add default mise install location to PATH so we can find it
    export PATH="${HOME}/.local/bin:${PATH}"

    # Find where mise was actually installed
    if ! mise_path=$(command -v mise 2>/dev/null); then
      local version_info=""
      [[ -n "${MISE_VERSION:-}" ]] && version_info=" (requested version: ${MISE_VERSION})"
      die "Mise installation failed - binary not found in PATH after installation${version_info}"
    fi

    if ! verify_mise_checksum; then
      echo "Warning: Could not verify mise checksum, but continuing..." >&2
    fi
  fi

  # Add mise binary directory to PATH first
  local mise_bin_dir
  mise_bin_dir="$(dirname "$mise_path")"
  export PATH="${mise_bin_dir}:${PATH}"

  # Trust devbase-core .mise.toml BEFORE activation (prevents trust warning)
  if [[ -f "${DEVBASE_ROOT}/.mise.toml" ]]; then
    "$mise_path" trust "${DEVBASE_ROOT}/.mise.toml" 2>/dev/null || true
  fi

  # Activate mise for current shell session
  # This sets up PATH and environment properly
  if [[ -x "$mise_path" ]]; then
    # Ensure PROMPT_COMMAND is set to avoid unbound variable error with set -u
    : "${PROMPT_COMMAND:=}"
    eval "$("$mise_path" activate bash)"
  else
    die "Mise binary exists but is not executable at $mise_path (permissions: $(ls -l "$mise_path" 2>&1))"
  fi

  # Verify mise is now in PATH
  if ! command -v mise &>/dev/null; then
    die "Mise installation failed - not found in PATH after activation"
  fi

  show_progress success "Mise ready at $mise_path"
}

install_mise_tools() {
  show_progress info "Installing development tools..."
  echo

  local mise_config="${DEVBASE_DOT}/.config/mise/config.toml"

  # Check for custom mise config override
  if [[ -n "${_DEVBASE_CUSTOM_PACKAGES}" ]] && [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/mise-config.toml" ]]; then
    mise_config="${_DEVBASE_CUSTOM_PACKAGES}/mise-config.toml"
    show_progress info "Using custom mise config: $mise_config"
  fi

  if [[ -f "$mise_config" ]]; then
    cp "$mise_config" "${XDG_CONFIG_HOME}/mise/config.toml"
  else
    die "Mise config not found at $mise_config"
  fi

  # Trust the config files (both user config and devbase-core root)
  run_mise_from_home_dir trust "${XDG_CONFIG_HOME}/mise/config.toml" 2>/dev/null || true
  run_mise_from_home_dir trust --all 2>/dev/null || true

  # Count already installed tools
  local tools_before
  tools_before=$(run_mise_from_home_dir list 2>/dev/null | wc -l)
  tools_before=${tools_before#0}
  tools_before=${tools_before:-0}

  # Install core runtimes first (required by npm/cargo/gem backends)
  # This ensures node, python, go, java are available before mise resolves npm:, cargo:, gem: tools
  show_progress info "Installing core language runtimes..."
  if ! run_mise_from_home_dir install node python go java maven gradle ruby --yes 2>&1; then
    show_progress warning "Some core runtimes may have failed (will retry with full install)"
  fi

  # Now count remaining tools to install (npm/cargo/gem tools can be resolved now)
  local tools_to_install
  tools_to_install=$(run_mise_from_home_dir list --not-installed 2>/dev/null | wc -l)
  tools_to_install=${tools_to_install#0}
  tools_to_install=${tools_to_install:-0}

  # Install all remaining tools
  show_progress info "Installing development tools..."
  # Run mise install with progress bar visible (no stderr redirection)
  # mise handles checksum verification internally and will fail if checksums don't match
  if ! run_mise_from_home_dir install --yes; then
    die "Mise tool installation failed"
  fi

  # Verify critical tools are present
  local critical_tools=("node" "python" "go" "java")
  local verified_count=0
  local missing=()

  for tool in "${critical_tools[@]}"; do
    if run_mise_from_home_dir which "$tool" &>/dev/null; then
      verified_count=$((verified_count + 1))
    else
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing critical development tools: ${missing[*]}"
  fi

  # Show summary
  local total_tools
  total_tools=$(run_mise_from_home_dir list 2>/dev/null | wc -l)

  local msg="Development tools ready ($total_tools total"
  [[ $tools_to_install -gt 0 ]] && msg="${msg}, $tools_to_install new"
  [[ $tools_before -gt 0 ]] && msg="${msg}, $tools_before cached"
  [[ $verified_count -gt 0 ]] && msg="${msg}, $verified_count runtimes verified"
  msg="${msg})"
  printf "\n"
  show_progress success "$msg"
}

# Brief: Install mise and all development tools (main entry point)
# Params: None
# Returns: 0 on success, calls die() on failure
# Side-effects: Full mise installation workflow
install_mise_and_tools() {
  load_all_versions || die "Failed to load tool versions"
  sync_mise_config_versions || die "Failed to sync mise config versions"
  install_mise || die "Failed to install mise"
  install_mise_tools || die "Failed to install mise tools"

  return 0
}
