#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

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

  # Map uname architecture to mise's binary naming convention.
  # Explicit table avoids the silent x86_64→x64 mismatch and makes
  # adding future architectures (armv7l, riscv64…) straightforward.
  local mise_arch
  case "$(uname -m)" in
  x86_64) mise_arch="x64" ;;    # mise ships as mise-vX.Y-linux-x64
  aarch64) mise_arch="arm64" ;; # mise ships as mise-vX.Y-linux-arm64
  *)
    die "Mise checksum verification not supported on architecture: $(uname -m). Install mise manually or skip with DEVBASE_STRICT_CHECKSUMS=warn"
    ;;
  esac

  # Get version from packages.yaml if not provided
  if [[ -z "$version" ]]; then
    [[ -n "${MISE_VERSION:-}" ]] && version="$MISE_VERSION"
    if [[ -z "$version" ]] && declare -f get_tool_version &>/dev/null; then
      version=$(get_tool_version "mise")
    fi
  fi

  if [[ -z "$version" ]]; then
    show_progress info "Mise version not yet available (first-run is OK); checksum verification will run after setup"
    return 0
  fi

  # Strip 'v' prefix if present
  version="${version#v}"

  local checksums_url="${DEVBASE_URL_MISE_RELEASES}/v${version}/SHASUMS256.txt"
  local checksums_file="${_DEVBASE_TEMP}/mise-checksums.txt"

  if ! retry_command curl -fsSL "$checksums_url" -o "$checksums_file"; then
    add_install_warning "Could not download checksums for mise v${version}"
    return 0
  fi

  local actual_checksum
  actual_checksum=$(sha256sum "$mise_bin" | cut -d' ' -f1)

  local binary_pattern="mise-v${version}-linux-${mise_arch}"
  local expected_checksum
  expected_checksum=$(grep "$binary_pattern" "$checksums_file" 2>/dev/null | head -1 | cut -d' ' -f1)
  if [[ -z "$expected_checksum" ]]; then
    add_install_warning "Could not find checksum for $binary_pattern"
    return 0
  fi

  if [[ "$actual_checksum" != "$expected_checksum" ]]; then
    show_progress error "Mise binary checksum mismatch!"
    show_progress info "Expected: $expected_checksum"
    show_progress info "Actual:   $actual_checksum"
    return 1
  fi
}

# Brief: Check if a log file contains mise HTTP server errors (5xx)
# Params: $1 = log file path
# Returns: 0 if server error found, 1 if not
_check_mise_server_error() {
  local log_file="$1"
  grep -qE "HTTP status server error \(50[0-9]" "$log_file" 2>/dev/null
}

# Brief: Apply mise tool PATH without eval by reading mise env output
# Params: $1 = mise path
# Returns: 0 on success, 1 on failure
# Notes: Uses `mise env -s bash` which outputs the full tool environment for
#        the current directory without requiring prior shell session state.
#        `mise activate bash` only installs shell hooks and does not expose
#        installed tool paths — wrong for script use.
_mise_apply_path_from_activate() {
  local mise_path="$1"

  # mise env outputs the complete environment for current directory tools;
  # suppress stderr (WARN: missing tool messages for not-yet-installed tools)
  local activation_output
  activation_output=$("$mise_path" env -s bash 2>/dev/null)

  local path_line
  path_line=$(printf '%s\n' "$activation_output" | grep -E '^export PATH=' | tail -1)
  if [[ -z "$path_line" ]]; then
    show_progress error "Failed to read mise PATH from env output"
    return 1
  fi

  local path_value="${path_line#export PATH=}"
  path_value="${path_value#\"}"
  path_value="${path_value%\"}"
  path_value="${path_value#\'}"
  path_value="${path_value%\'}"
  path_value="${path_value//\$PATH/$PATH}"

  if [[ "$path_value" == *'$'* ]]; then
    show_progress error "Unsupported mise PATH activation output"
    return 1
  fi

  export PATH="$path_value"
}

# Brief: Get the installed version of a mise binary
# Params: $1 - path to mise binary
# Returns: version string (without leading v) on stdout, 1 if not found or unreadable
get_mise_installed_version() {
  local mise_path="$1"
  [[ -z "$mise_path" ]] && return 1

  local version
  version=$($mise_path --version 2>/dev/null | grep -oE 'v?[0-9]+(\.[0-9]+)+' | head -1)
  version="${version#v}"
  [[ -n "$version" ]] && printf '%s\n' "$version"
}

# Brief: Download, verify checksum, and run the mise installer script
# Params: $1 - progress label shown in the spinner/output (e.g. "Installing mise")
# Uses: DEVBASE_URL_MISE_INSTALLER, _DEVBASE_TEMP, DEVBASE_TUI_MODE,
#       MISE_VERSION (optional, set by caller before invoking)
# Returns: calls die() on any failure (download, validation, or run)
# Side-effects: Runs installer; adds ~/.local/bin to PATH once (idempotent guard)
_run_mise_installer() {
  local label="${1:-Installing mise}"
  local mise_installer="${_DEVBASE_TEMP}/mise_installer.sh"

  if ! download_file "$DEVBASE_URL_MISE_INSTALLER" "$mise_installer"; then
    die "Failed to download Mise installer"
  fi

  # A valid installer must be non-empty, start with a shell shebang (rules out
  # HTML error pages and truncated downloads), and mention "mise" somewhere in
  # its body.  The checksum verification that follows is the real integrity
  # check; this is a fast sanity gate for obviously wrong files.
  if [[ ! -s "$mise_installer" ]] ||
    ! grep -qE '^#!/.*(ba)?sh' "$mise_installer" ||
    ! grep -q 'mise' "$mise_installer"; then
    die "Downloaded file doesn't appear to be Mise installer"
  fi

  if [[ -z "${DEVBASE_MISE_INSTALLER_SHA256:-}" ]]; then
    show_progress error "DEVBASE_MISE_INSTALLER_SHA256 not set; refusing to run mise installer"
    die "Mise installer checksum verification failed"
  fi
  show_progress info "Verifying mise installer checksum"
  if ! verify_checksum_value "$mise_installer" "${DEVBASE_MISE_INSTALLER_SHA256}"; then
    die "Mise installer checksum verification failed"
  fi

  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then
    run_with_spinner "$label" bash "$mise_installer" || die "Failed to run Mise installer script"
  else
    bash "$mise_installer" || die "Failed to run Mise installer script"
  fi

  # Add the default mise install location to PATH once.  The guard prevents
  # a duplicate entry when both install_mise and update_mise_if_needed run
  # in the same session.
  [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]] && export PATH="${HOME}/.local/bin:${PATH}"
}

# Brief: Install mise tool version manager
# Params: None
# Uses: _DEVBASE_TEMP, HOME, XDG_BIN_HOME, DEVBASE_URL_MISE_INSTALLER (globals)
# Returns: 0 on success, calls die() on fatal failure
# Side-effects: Downloads and installs mise, bootstraps yq/just, activates mise on PATH
install_mise() {
  show_progress info "Installing mise (tool version manager)..."

  local mise_path=""

  if command -v /usr/bin/mise &>/dev/null || dpkg -l mise 2>/dev/null | grep -q '^ii'; then
    show_progress info "Purging apt-installed mise to use DevBase version..."
    if ! sudo apt-get purge -y mise; then
      die "Failed to purge apt-installed mise. Please remove it and rerun."
    fi

    # Clean up fish hooks that hardcode /usr/bin/mise (from apt package)
    local fish_user_hooks=(
      "$HOME/.config/fish/functions/fish_command_not_found.fish"
      "$HOME/.config/fish/conf.d/mise.fish"
    )
    for file in "${fish_user_hooks[@]}"; do
      if [[ -f "$file" ]] && grep -q "/usr/bin/mise" "$file" 2>/dev/null; then
        rm -f "$file"
      fi
    done

    local fish_vendor_hooks=(
      "/usr/share/fish/vendor_conf.d/mise.fish"
      "/usr/share/fish/vendor_functions.d/fish_command_not_found.fish"
    )
    for file in "${fish_vendor_hooks[@]}"; do
      if [[ -f "$file" ]] && grep -q "/usr/bin/mise" "$file" 2>/dev/null; then
        sudo rm -f "$file" 2>/dev/null || true
      fi
    done
  fi

  if command -v "${XDG_BIN_HOME}/mise" &>/dev/null; then
    mise_path="${XDG_BIN_HOME}/mise"
  elif command_exists mise; then
    mise_path="$(command -v mise)"
  fi

  if [[ -z "$mise_path" ]]; then
    # Set MISE_VERSION from packages.yaml so the installer downloads the
    # pinned version; unset means the installer picks the latest release.
    local mise_version=""
    if declare -f get_tool_version &>/dev/null; then
      mise_version=$(get_tool_version "mise")
    fi
    [[ -n "$mise_version" ]] && export MISE_VERSION="$mise_version"

    _run_mise_installer "Installing mise"

    # Find where mise was actually installed
    if ! mise_path=$(command -v mise 2>/dev/null); then
      die "Mise installation failed - binary not found in PATH after installation${MISE_VERSION:+ (requested version: ${MISE_VERSION})}"
    fi

    if ! verify_mise_checksum; then
      add_install_warning "Could not verify mise checksum, but continuing..."
    fi
  fi

  # Add mise binary directory to PATH first
  export PATH="$(dirname "$mise_path"):${PATH}"

  # Trust devbase-core .mise.toml BEFORE activation (prevents trust warning)
  if [[ -f "${DEVBASE_ROOT}/.mise.toml" ]]; then
    "$mise_path" trust "${DEVBASE_ROOT}/.mise.toml" 2>/dev/null || true
  fi

  # Bootstrap essential tools early - required before full tool installation
  # yq: needed by parse-packages.sh for YAML parsing
  # just: task runner used by devbase
  if [[ -f "${DEVBASE_ROOT}/.mise.toml" ]]; then
    local yq_tool="aqua:mikefarah/yq"
    show_progress info "Bootstrapping essential tools (yq)..."
    if ! "$mise_path" install "$yq_tool" --yes 2>/dev/null; then
      die "Failed to bootstrap yq via mise"
    fi

    # Activate mise so yq is available on PATH
    _mise_apply_path_from_activate "$mise_path" || die "Failed to activate mise PATH"

    if ! command -v yq &>/dev/null; then
      die "yq not found after mise bootstrap"
    fi

    if ! command -v just &>/dev/null; then
      show_progress info "Bootstrapping essential tools (just)..."
      if ! "$mise_path" install just --yes 2>/dev/null; then
        add_install_warning "Failed to bootstrap just (continuing)"
      fi
    fi
  fi

  # Generate mise config before activation to avoid stale tool warnings
  if ! declare -f generate_mise_config &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh" || die "Failed to load package parser (is yq installed?)"
  fi

  _setup_package_yaml_env || true

  if [[ -f "$PACKAGES_YAML" ]]; then

    local mise_config="${XDG_CONFIG_HOME}/mise/config.toml"
    mkdir -p "$(dirname "$mise_config")"
    generate_mise_config "$mise_config"
    show_progress info "Generated mise config from packages.yaml"
  fi

  # Activate mise for current shell session
  # This sets up PATH and environment properly
  if [[ -x "$mise_path" ]]; then
    _mise_apply_path_from_activate "$mise_path" || die "Failed to activate mise PATH"
  else
    die "Mise binary exists but is not executable at $mise_path (permissions: $(ls -l "$mise_path" 2>&1))"
  fi

  # Verify mise is now in PATH
  if ! command -v mise &>/dev/null; then
    die "Mise installation failed - not found in PATH after activation"
  fi

  show_progress success "Mise ready at $mise_path"
}

# Brief: Upgrade mise to the pinned version if it is installed and behind
# Params: None
# Uses: get_tool_version, get_mise_installed_version, _run_mise_installer, verify_mise_checksum (globals)
# Returns: 0 always (non-fatal; warnings added for checksum failure or downgrade skips)
# Side-effects: Runs mise installer, may update binary in PATH
update_mise_if_needed() {
  if ! command -v mise &>/dev/null; then
    return 0
  fi

  if ! declare -f get_tool_version &>/dev/null; then
    return 0
  fi

  local desired_version
  desired_version=$(get_tool_version "mise")
  [[ -z "$desired_version" ]] && return 0

  local desired_normalized="${desired_version#v}"
  local current_version
  current_version=$(get_mise_installed_version "$(command -v mise)")

  if [[ -n "$current_version" ]]; then
    [[ "$current_version" == "$desired_normalized" ]] && return 0

    local newest
    newest=$(printf '%s\n%s\n' "$current_version" "$desired_normalized" | sort -V | tail -1)
    [[ "$newest" == "$current_version" ]] && {
      add_install_warning "Installed mise (${current_version}) is newer than pinned (${desired_normalized}) - skipping downgrade"
      return 0
    }
  fi

  show_progress info "Updating mise to v${desired_normalized}..."

  export MISE_VERSION="$desired_version"
  _run_mise_installer "Updating mise"

  if ! verify_mise_checksum "$desired_version"; then
    add_install_warning "Could not verify mise checksum, but continuing..."
  fi
}

# Brief: Run full mise install with whiptail progress gauge
# Params: $1-full_install_log $2-tools_to_install $3-nameref for mise_server_error
_install_mise_tools_whiptail_gauge() {
  local full_install_log="$1"
  local tools_to_install="$2"
  local -n _gauge_server_error="$3"

  local count=0
  local total="$tools_to_install"
  local install_exit_code=0
  local _ec_file
  _ec_file=$(mktemp)

  [[ $total -eq 0 ]] && total=1 # Avoid division by zero
  _wt_update_gauge "Installing development tools (0/$total)..." 0

  while IFS= read -r line; do
    echo "$line" >>"$full_install_log"
    if [[ "$line" =~ installed ]] || [[ "$line" =~ "install "[a-z] ]]; then
      local tool
      tool=$(printf '%s\n' "$line" | grep -oE '[a-z][a-z0-9_-]*@[^ ]+' | head -1)
      if [[ -n "$tool" ]]; then
        count=$((count + 1))
        local percent=$(((count * 100) / total))
        _wt_update_gauge "Installed: $tool ($count/$total)" "$percent"
      fi
    fi
  done < <(
    run_mise_from_home_dir install --yes 2>&1
    printf '%s' "$?" >"$_ec_file"
  )

  install_exit_code=$(cat "$_ec_file" 2>/dev/null)
  install_exit_code=${install_exit_code:-1}
  rm -f "$_ec_file"

  [[ $count -eq 0 ]] && [[ $tools_to_install -gt 0 ]] &&
    add_install_warning "Could not parse mise progress output"
  _check_mise_server_error "$full_install_log" && _gauge_server_error=true
  [[ $install_exit_code -ne 0 ]] && add_install_warning "mise install returned non-zero exit code"
}

# Brief: Run full mise install with whiptail spinner (no persistent gauge)
# Params: $1-full_install_log $2-nameref for mise_server_error
_install_mise_tools_whiptail_spinner() {
  local full_install_log="$1"
  local -n _spinner_server_error="$2"

  # run_with_spinner/_wt_run_with_spinner backgrounds the command in a new
  # process that does not inherit set -o pipefail from the parent shell.
  # Without pipefail the pipeline exit code is tee's (always 0), silently
  # masking a failing mise install. Explicitly setting pipefail in the
  # subprocess makes the pipeline exit with mise's exit code, which
  # _wt_run_with_spinner then captures correctly via wait().
  if ! run_with_spinner "Installing development tools (mise)" \
    bash -c "set -o pipefail
		         $(declare -f run_mise_from_home_dir)
		         run_mise_from_home_dir install --yes 2>&1 | tee '${full_install_log}'"; then
    _check_mise_server_error "$full_install_log" && _spinner_server_error=true
    add_install_warning "mise install returned non-zero exit code"
  fi
}

# Brief: Run full mise install with gum/interactive output
# Params: $1-full_install_log $2-nameref for mise_server_error
_install_mise_tools_gum() {
  local full_install_log="$1"
  local -n _gum_server_error="$2"

  show_progress info "Installing development tools..."
  if ! run_mise_from_home_dir install --yes 2>&1 | tee "$full_install_log"; then
    add_install_warning "mise install returned non-zero exit code"
  fi
  _check_mise_server_error "$full_install_log" && _gum_server_error=true
}

install_mise_tools() {
  show_progress info "Installing development tools..."
  tui_blank_line

  # Trust the config files (both user config and devbase-core root)
  run_mise_from_home_dir trust "${XDG_CONFIG_HOME}/mise/config.toml" 2>/dev/null || true
  run_mise_from_home_dir trust --all 2>/dev/null || true

  # Install core runtimes FIRST (required by npm/cargo/gem backends)
  # This MUST happen before any `mise list` commands, because mise tries to resolve
  # all tools in config.toml (including npm:tree-sitter-cli) which requires node
  local -a core_runtimes=()
  while IFS= read -r runtime; do
    [[ -n "$runtime" ]] && core_runtimes+=("$runtime")
  done < <(get_core_runtimes)

  local mise_server_error=false
  if [[ ${#core_runtimes[@]} -gt 0 ]]; then
    local core_install_log="${_DEVBASE_TEMP}/mise-core-install.log"

    if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then
      # Whiptail mode - use spinner with gauge; pass array via declare -p
      if ! run_with_spinner "Installing core language runtimes" \
        bash -c "$(declare -p core_runtimes); $(declare -f run_mise_from_home_dir); run_mise_from_home_dir install \"\${core_runtimes[@]}\" --yes 2>&1 | tee '$core_install_log'"; then
        if _check_mise_server_error "$core_install_log"; then
          mise_server_error=true
        fi
        add_install_warning "Some core runtimes may have failed (will retry with full install)"
      fi
    else
      # Gum/other mode - show real-time output
      show_progress info "Installing core language runtimes..."
      if ! run_mise_from_home_dir install "${core_runtimes[@]}" --yes 2>&1 | tee "$core_install_log"; then
        if _check_mise_server_error "$core_install_log"; then
          mise_server_error=true
        fi
        add_install_warning "Some core runtimes may have failed (will retry with full install)"
      fi
    fi
  fi

  # Now that core runtimes are installed, we can safely query tool counts
  # (npm:, cargo:, gem: tools can now be resolved)
  local tools_before
  tools_before=$(($(run_mise_from_home_dir list 2>/dev/null | wc -l)))

  local tools_to_install
  tools_to_install=$(($(run_mise_from_home_dir list --not-installed 2>/dev/null | wc -l)))

  # Install all remaining tools via the appropriate TUI path
  local full_install_log="${_DEVBASE_TEMP}/mise-full-install.log"

  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && _wt_gauge_is_running; then
    _install_mise_tools_whiptail_gauge "$full_install_log" "$tools_to_install" mise_server_error
  elif [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then
    _install_mise_tools_whiptail_spinner "$full_install_log" mise_server_error
  else
    _install_mise_tools_gum "$full_install_log" mise_server_error
  fi

  # Verify critical tools are present (based on selected packs)
  # Only verify the core runtime for each selected pack
  # Second pass to catch transient install failures (quiet unless it fails)
  local second_install_log="${_DEVBASE_TEMP}/mise-second-install.log"
  if ! run_mise_from_home_dir install --yes &>"$second_install_log"; then
    add_install_warning "Second mise install pass failed"
    add_install_warning "See log: $second_install_log"
  fi
  if ! run_mise_from_home_dir reshim &>>"$second_install_log"; then
    add_install_warning "mise reshim failed"
    add_install_warning "See log: $second_install_log"
  fi
  if ! run_mise_from_home_dir prune --tools &>>"$second_install_log"; then
    add_install_warning "mise prune failed"
    add_install_warning "See log: $second_install_log"
  fi

  local verified_count=0
  local missing=()

  # Map pack to its primary runtime binary
  for pack in $DEVBASE_SELECTED_PACKS; do
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
      add_install_warning "This is a temporary issue with mise infrastructure. Please try again later:"
      show_progress info "  mise install ${missing[*]}"
      die "Setup cannot continue without critical development tools"
    fi
    die "Missing critical development tools: ${missing[*]}"
  fi

  # Warn if starship is missing (shell prompt depends on it)
  if ! run_mise_from_home_dir which starship &>/dev/null; then
    add_install_warning "Starship not found after install"
    show_progress info "  Install with: mise install aqua:starship/starship"
  fi

  # Show summary
  local total_tools
  total_tools=$(run_mise_from_home_dir list 2>/dev/null | wc -l)

  local msg="Development tools ready ($total_tools total"
  [[ $tools_to_install -gt 0 ]] && msg="${msg}, $tools_to_install new"
  [[ $tools_before -gt 0 ]] && msg="${msg}, $tools_before cached"
  [[ $verified_count -gt 0 ]] && msg="${msg}, $verified_count runtimes verified"
  msg="${msg})"
  tui_blank_line
  show_progress success "$msg"
}

# Brief: Install mise and all development tools (main entry point)
# Params: None
# Returns: 0 on success, calls die() on failure
# Side-effects: Full mise installation workflow
install_mise_and_tools() {
  install_mise || die "Failed to install mise"

  # Source parser for version lookups (requires yq; should exist after mise bootstrap)
  if ! declare -f get_tool_version &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh" || die "Failed to load package parser (is yq installed?)"
  fi

  update_mise_if_needed || die "Failed to update mise"

  install_mise_tools || die "Failed to install mise tools"

  return 0
}
