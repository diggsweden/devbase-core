#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Brief: Verify mise binary checksum against official release checksums
# Params: $1 = version (optional, uses get_tool_version if not provided)
# Uses: XDG_BIN_HOME, _DEVBASE_TEMP, retry_command (globals/functions)
# Returns: 0 if valid or skipped, 1 if mise not found or checksum mismatch
# Side-effects: Downloads SHASUMS256.txt, computes sha256sum
verify_mise_checksum() {
  local version="${1:-}"
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

  # Get version from packages.yaml if not provided
  if [[ -z "$version" ]]; then
    if declare -f get_tool_version &>/dev/null; then
      version=$(get_tool_version "mise")
    fi
  fi

  if [[ -z "$version" ]]; then
    echo "Warning: Could not determine expected mise version" >&2
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

    # Get mise version from packages.yaml via parser
    local mise_version=""
    if declare -f get_tool_version &>/dev/null; then
      mise_version=$(get_tool_version "mise")
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

  # Generate mise config from packages.yaml
  # shellcheck disable=SC2153  # DEVBASE_DOT is set by setup.sh, not a typo of DEVBASE_ROOT
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export SELECTED_PACKS="${DEVBASE_SELECTED_PACKS:-java node python go ruby rust vscode-editor}"

  # Check for custom packages override
  if [[ -n "${_DEVBASE_CUSTOM_PACKAGES:-}" ]] && [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml" ]]; then
    export PACKAGES_CUSTOM_YAML="${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml"
    show_progress info "Using custom package overrides"
  fi

  if [[ ! -f "$PACKAGES_YAML" ]]; then
    die "Package configuration not found: $PACKAGES_YAML"
  fi

  # Source parser if not already loaded
  if ! declare -f generate_mise_config &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh"
  fi

  # Generate mise config.toml from packages.yaml
  local mise_config="${XDG_CONFIG_HOME}/mise/config.toml"
  mkdir -p "$(dirname "$mise_config")"
  generate_mise_config "$mise_config"
  show_progress info "Generated mise config from packages.yaml"

  # Trust the config files (both user config and devbase-core root)
  run_mise_from_home_dir trust "${XDG_CONFIG_HOME}/mise/config.toml" 2>/dev/null || true
  run_mise_from_home_dir trust --all 2>/dev/null || true

  # Install core runtimes FIRST (required by npm/cargo/gem backends)
  # This MUST happen before any `mise list` commands, because mise tries to resolve
  # all tools in config.toml (including npm:tree-sitter-cli) which requires node
  # We filter the npm:tree-sitter-cli warning since node isn't installed yet
  local core_runtimes
  core_runtimes=$(get_core_runtimes)

  local mise_server_error=false
  if [[ -n "$core_runtimes" ]]; then
    show_progress info "Installing core language runtimes..."
    local core_install_output
    # shellcheck disable=SC2086 # Word splitting intended for runtime list
    if ! core_install_output=$(run_mise_from_home_dir install $core_runtimes --yes 2>&1); then
      # Check for HTTP 5xx server errors (temporary mise infrastructure issues)
      if echo "$core_install_output" | grep -qE "HTTP status server error \(50[0-9]"; then
        mise_server_error=true
      fi
      # Filter out expected warning about npm:tree-sitter-cli not being resolvable yet
      echo "$core_install_output" | grep -v "Failed to resolve tool version list for npm:tree-sitter-cli" || true
      show_progress warning "Some core runtimes may have failed (will retry with full install)"
    else
      # Show output but filter the npm:tree-sitter-cli warning
      echo "$core_install_output" | grep -v "Failed to resolve tool version list for npm:tree-sitter-cli" || true
    fi
  fi

  # Now that core runtimes are installed, we can safely query tool counts
  # (npm:, cargo:, gem: tools can now be resolved)
  local tools_before
  tools_before=$(run_mise_from_home_dir list 2>/dev/null | wc -l)
  tools_before=${tools_before#0}
  tools_before=${tools_before:-0}

  local tools_to_install
  tools_to_install=$(run_mise_from_home_dir list --not-installed 2>/dev/null | wc -l)
  tools_to_install=${tools_to_install#0}
  tools_to_install=${tools_to_install:-0}

  # Install all remaining tools
  show_progress info "Installing development tools..."
  # Run mise install with progress bar visible (no stderr redirection)
  # mise handles checksum verification internally and will fail if checksums don't match
  local full_install_output
  if ! full_install_output=$(run_mise_from_home_dir install --yes 2>&1); then
    echo "$full_install_output"
    # Check for HTTP 5xx server errors (temporary mise infrastructure issues)
    if echo "$full_install_output" | grep -qE "HTTP status server error \(50[0-9]"; then
      mise_server_error=true
    fi
  else
    echo "$full_install_output"
  fi

  # Verify critical tools are present (based on selected packs)
  # Only verify the core runtime for each selected pack
  local verified_count=0
  local missing=()

  # Map pack to its primary runtime binary
  for pack in $SELECTED_PACKS; do
    local tool=""
    case "$pack" in
    node) tool="node" ;;
    python) tool="python" ;;
    go) tool="go" ;;
    java) tool="java" ;;
    ruby) tool="ruby" ;;
    rust) tool="rustc" ;;
    esac
    [[ -z "$tool" ]] && continue

    if run_mise_from_home_dir which "$tool" &>/dev/null; then
      verified_count=$((verified_count + 1))
    else
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    if [[ "$mise_server_error" == "true" ]]; then
      show_progress error "Missing tools (${missing[*]}) due to mise server errors (HTTP 5xx)"
      show_progress warning "This is a temporary issue with mise infrastructure. Please try again later:"
      show_progress info "  mise install ${missing[*]}"
      die "Setup cannot continue without critical development tools"
    fi
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
  # Set up package configuration
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export SELECTED_PACKS="${DEVBASE_SELECTED_PACKS:-java node python go ruby rust vscode-editor}"

  # Check for custom packages override
  if [[ -n "${_DEVBASE_CUSTOM_PACKAGES:-}" ]] && [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml" ]]; then
    export PACKAGES_CUSTOM_YAML="${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml"
  fi

  # Source parser for version lookups
  if ! declare -f get_tool_version &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh"
  fi

  install_mise || die "Failed to install mise"
  install_mise_tools || die "Failed to install mise tools"

  return 0
}
