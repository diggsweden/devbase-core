#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1 2>/dev/null || exit 1
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
validate_critical_versions() {
  local critical_tools=("nodejs" "python" "java_jdk" "golang")
  local missing_versions=()

  for tool in "${critical_tools[@]}"; do
    if [[ -z "${TOOL_VERSIONS[$tool]:-}" ]]; then
      missing_versions+=("$tool")
    fi
  done

  if [[ ${#missing_versions[@]} -gt 0 ]]; then
    show_progress warning "${missing_versions[*]}"
    printf "    %b Check custom-tools.yaml format\n" "${DEVBASE_COLORS[DIM]}ℹ${DEVBASE_COLORS[NC]}"
  fi
  return 0
}

# Brief: Update mise config.toml with versions from TOOL_VERSIONS
# Params: None
# Uses: TOOL_VERSIONS, DEVBASE_DOT, _DEVBASE_TEMP (globals)
# Returns: 0 always
# Side-effects: Modifies mise config.toml in dotfiles
sync_mise_config_versions() {
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

  if ! [[ -f "$versions_file" ]]; then
    echo "Warning: Could not determine expected mise version from custom-tools.yaml" >&2
    return 0
  fi

  # Strip 'v' prefix if present
  version="${version#v}"

  local checksums_url="https://github.com/jdx/mise/releases/download/v${version}/SHASUMS256.txt"
  local checksums_file="${_DEVBASE_TEMP}/mise-checksums.txt"

  if ! retry_command curl -fsSL "$checksums_url" -o "$checksums_file" 2>/dev/null; then
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
  elif command -v "${HOME}/.local/bin/mise" &>/dev/null; then
    mise_path="${HOME}/.local/bin/mise"
  elif command_exists mise; then
    mise_path="$(command -v mise)"
  fi

  if [[ -z "$mise_path" ]]; then
    # Install mise to ~/.local/bin
    local mise_installer="${_DEVBASE_TEMP}/mise_installer.sh"

    if ! retry_command download_file "https://mise.run" "$mise_installer"; then
      die "Failed to download Mise installer after retries"
    fi

    if [[ ! -s "$mise_installer" ]] || ! grep -q "mise" "$mise_installer"; then
      die "Downloaded file doesn't appear to be Mise installer"
    fi

    # Get mise version from custom-tools.yaml
    local expected_mise_version=""
    if [[ -n "${TOOL_VERSIONS[mise]:-}" ]]; then
      # Fallback: read directly from custom-tools.yaml if TOOL_VERSIONS not populated yet
      local versions_file="${DEVBASE_DOT}/.config/devbase/custom-tools.yaml"
      if [[ -f "$versions_file" ]]; then
        mise_version=$(grep "^mise:" "$versions_file" | head -1 | awk '{print $2}' | sed 's/#.*//' | tr -d ' ')
      fi
    fi

    # Ensure mise installs to ~/.local/bin with specified version
    export MISE_INSTALL_PATH="${HOME}/.local/bin/mise"
    if [[ -n "$mise_version" ]]; then
      export MISE_VERSION="$mise_version"
    fi
    bash "$mise_installer" || die "Failed to install Mise"

    if ! verify_mise_checksum; then
      echo "Warning: Could not verify mise checksum, but continuing..." >&2
    fi

    mise_path="${HOME}/.local/bin/mise"
  fi

  # Add mise binary directory to PATH first
  export PATH="${HOME}/.local/bin:${PATH}"

  # Activate mise for current shell session
  # This sets up PATH and environment properly
  if [[ -x "${HOME}/.local/bin/mise" ]]; then
    eval "$("${HOME}/.local/bin/mise" activate bash)"
  else
    die "Mise installation failed - binary not found at ${HOME}/.local/bin/mise"
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

  if [[ -f "${DEVBASE_DOT}/.config/mise/config.toml" ]]; then
    cp "${DEVBASE_DOT}/.config/mise/config.toml" "${XDG_CONFIG_HOME}/mise/config.toml"
  else
    die "Mise config not found in ${DEVBASE_DOT}/.config/mise/config.toml"
  fi

  # Trust the config file we just copied
  mise trust --all || true

  local tools_before
  tools_before=$(run_mise_from_home_dir list 2>/dev/null | wc -l)
  local tools_to_install
  tools_to_install=$(run_mise_from_home_dir list --not-installed 2>/dev/null | wc -l)

  tools_before=${tools_before#0}
  tools_to_install=${tools_to_install#0}
  tools_before=${tools_before:-0}
  tools_to_install=${tools_to_install:-0}

  # Capture stderr to check for checksum failures
  local mise_stderr="${_DEVBASE_TEMP}/mise_install_stderr.txt"
  run_mise_from_home_dir install --yes 2>"$mise_stderr"
  local mise_status=$?

  # Check for checksum failures in stderr - these are SECURITY CRITICAL
  if grep -iE "(checksum|sha256|hash).*(mismatch|fail|invalid|incorrect)" "$mise_stderr" 2>/dev/null; then
    echo "" >&2
    show_progress error "SECURITY: Checksum verification failed during mise tool installation" >&2
    show_progress warning "This indicates potential security risks:" >&2
    show_progress warning "  - Man-in-the-middle attack" >&2
    show_progress warning "  - Corrupted download mirror" >&2
    show_progress warning "  - Tampered package" >&2
    echo "" >&2
    show_progress info "Error details:" >&2
    cat "$mise_stderr" >&2
    die "Aborting installation due to checksum verification failure"
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

  if [[ $mise_status -ne 0 ]]; then
    show_progress warning "Some optional mise tools failed to install (non-critical)"
  fi

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
