#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1
fi

# Brief: Map uname architecture to mise's release-asset naming convention
# Returns: 0 with arch on stdout (x64/arm64), 1 on unsupported arch
_get_mise_arch() {
  case "$(uname -m)" in
  x86_64) echo "x64" ;;    # mise ships as mise-vX.Y-linux-x64
  aarch64) echo "arm64" ;; # mise ships as mise-vX.Y-linux-arm64
  *) return 1 ;;
  esac
}

# Brief: Read mise version from a packages.yaml without requiring yq.
# Used during first-run bootstrap, before yq is available — yq itself is
# what mise is about to install. Matches only the inline-flow form used
# in core.custom (e.g. `mise: {version: "v2026.4.24", installer: ...}`),
# which is the canonical form in the shipped packages.yaml. Custom
# overrides should follow the same form to be picked up here; otherwise
# the user can set MISE_VERSION explicitly.
# Params: $1 = path to a packages.yaml file
# Returns: 0 with version on stdout, 1 if no version found
_read_mise_version_from_yaml() {
  local yaml="$1"
  [[ -f "$yaml" ]] || return 1

  local line
  line=$(grep -E '^[[:space:]]+mise:[[:space:]]*\{[^}]*version:' "$yaml" | head -1)
  [[ -z "$line" ]] && return 1

  local version
  version=$(printf '%s' "$line" | sed -nE 's/.*version:[[:space:]]*"([^"]+)".*/\1/p')
  [[ -z "$version" ]] && return 1
  printf '%s\n' "$version"
}

# Brief: Resolve the target mise version (without leading 'v')
# Uses: MISE_VERSION (env), get_tool_version (function from parse-packages.sh),
#       PACKAGES_CUSTOM_YAML, _DEVBASE_CUSTOM_PACKAGES, PACKAGES_YAML, DEVBASE_DOT
# Returns: 0 with version on stdout, 1 if unresolved
# Notes: First-run bootstrap installs mise *before* parse-packages.sh can be
#        sourced (the parser requires yq, which mise is about to install).
#        In that window neither MISE_VERSION nor get_tool_version is set, so
#        we fall back to reading packages.yaml directly with grep/sed.
_get_mise_target_version() {
  local version="${MISE_VERSION:-}"
  if [[ -z "$version" ]] && declare -f get_tool_version &>/dev/null; then
    version=$(get_tool_version "mise")
  fi

  if [[ -z "$version" ]]; then
    # Custom yaml overrides base, matching the merge order in parse-packages.sh
    local custom_yaml="${PACKAGES_CUSTOM_YAML:-}"
    if [[ -z "$custom_yaml" && -n "${_DEVBASE_CUSTOM_PACKAGES:-}" ]]; then
      custom_yaml="${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml"
    fi
    [[ -n "$custom_yaml" ]] && version=$(_read_mise_version_from_yaml "$custom_yaml" 2>/dev/null || true)

    if [[ -z "$version" ]]; then
      local base_yaml="${PACKAGES_YAML:-}"
      [[ -z "$base_yaml" && -n "${DEVBASE_DOT:-}" ]] && base_yaml="${DEVBASE_DOT}/.config/devbase/packages.yaml"
      [[ -n "$base_yaml" ]] && version=$(_read_mise_version_from_yaml "$base_yaml" 2>/dev/null || true)
    fi
  fi

  [[ -z "$version" ]] && return 1
  printf '%s\n' "${version#v}"
}

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

  local mise_arch
  if ! mise_arch=$(_get_mise_arch); then
    die "Mise checksum verification not supported on architecture: $(uname -m). Install mise manually or skip with DEVBASE_STRICT_CHECKSUMS=warn"
  fi

  if [[ -z "$version" ]]; then
    if ! version=$(_get_mise_target_version); then
      show_progress info "Mise version not yet available (first-run is OK); checksum verification will run after setup"
      return 0
    fi
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
#
#        Runs from $HOME, not the caller's CWD. setup.sh is typically invoked
#        from DEVBASE_ROOT, whose .mise.toml may pin tool versions that aren't
#        yet installed during bootstrap (e.g. yq v4.52.5 vs the v4.52.4 we
#        bootstrap). `mise env` from there would emit a PATH for the pinned
#        version's (non-existent) install dir, hiding the bootstrap binary
#        we just installed via `use -g`. From $HOME only the global config
#        applies, which is exactly what install_mise needs.
_mise_apply_path_from_activate() {
  local mise_path="$1"

  # mise env outputs the complete environment for current directory tools;
  # suppress stderr (WARN: missing tool messages for not-yet-installed tools)
  local activation_output
  activation_output=$(cd "$HOME" && "$mise_path" env -s bash 2>/dev/null)

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

# Brief: Install mise binary from the official GitHub release tarball
# Params: $1 - progress label shown in the spinner/output (e.g. "Installing mise")
# Uses: DEVBASE_URL_MISE_RELEASES, _DEVBASE_TEMP, XDG_BIN_HOME, DEVBASE_TUI_MODE
#       MISE_VERSION (optional, falls back to get_tool_version "mise")
# Returns: calls die() on any failure (download, checksum, extract)
# Side-effects: Writes ${XDG_BIN_HOME}/mise; adds ~/.local/bin to PATH once
# Notes: Deliberately bypasses the upstream mise.run script — its default CDN
#        (mise.en.dev) is blocked by some egress proxies, and its only documented
#        knob (MISE_INSTALL_FROM_GITHUB) is undocumented in the project README.
#        Going straight to GitHub releases keeps this install path under our
#        control: one URL pattern, one SHASUMS256.txt for verification, no
#        chained shell script with version-dependent branching.
_run_mise_installer() {
  local label="${1:-Installing mise}"

  local mise_arch
  if ! mise_arch=$(_get_mise_arch); then
    die "Mise install not supported on architecture: $(uname -m)"
  fi

  local version
  if ! version=$(_get_mise_target_version); then
    die "Cannot determine mise version (set MISE_VERSION or pin in packages.yaml)"
  fi

  local asset="mise-v${version}-linux-${mise_arch}.tar.gz"
  local tarball_url="${DEVBASE_URL_MISE_RELEASES}/v${version}/${asset}"
  local checksums_url="${DEVBASE_URL_MISE_RELEASES}/v${version}/SHASUMS256.txt"
  local tarball="${_DEVBASE_TEMP}/${asset}"
  local checksums_file="${_DEVBASE_TEMP}/mise-shasums-v${version}.txt"

  # Fetch the checksums manifest with raw curl: this file is the trust anchor
  # for the tarball below, so it cannot itself be checksum-verified (would be
  # circular). Trust comes from HTTPS + the github.com domain pin. Same pattern
  # used by verify_mise_checksum and get_oc_checksum.
  if ! retry_command curl -fsSL "$checksums_url" -o "$checksums_file"; then
    die "Failed to download mise SHASUMS256.txt for v${version}"
  fi

  local expected_checksum
  expected_checksum=$(grep -F "$asset" "$checksums_file" 2>/dev/null | head -1 | awk '{print $1}')
  if [[ -z "$expected_checksum" ]]; then
    die "No checksum found for $asset in SHASUMS256.txt"
  fi

  if ! download_file "$tarball_url" "$tarball" "" "$expected_checksum"; then
    die "Failed to download or verify mise tarball v${version}"
  fi

  local extract_dir="${_DEVBASE_TEMP}/mise-extract-v${version}"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"

  local extract_cmd=(tar -C "$extract_dir" -xzf "$tarball")
  if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]]; then
    run_with_spinner "$label" "${extract_cmd[@]}" || die "Failed to extract mise tarball"
  else
    show_progress info "$label (v${version})"
    "${extract_cmd[@]}" || die "Failed to extract mise tarball"
  fi

  if [[ ! -f "$extract_dir/mise/bin/mise" ]]; then
    die "Extracted mise tarball has unexpected layout: missing mise/bin/mise"
  fi

  mkdir -p "$XDG_BIN_HOME"
  mv -f "$extract_dir/mise/bin/mise" "$XDG_BIN_HOME/mise"
  chmod +x "$XDG_BIN_HOME/mise"
  rm -rf "$extract_dir"

  # Add the default mise install location to PATH once.  The guard prevents
  # a duplicate entry when both install_mise and update_mise_if_needed run
  # in the same session.
  [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]] && export PATH="${HOME}/.local/bin:${PATH}"
}

# Brief: Install mise tool version manager
# Params: None
# Uses: _DEVBASE_TEMP, HOME, XDG_BIN_HOME, DEVBASE_URL_MISE_RELEASES (globals)
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
      "${XDG_CONFIG_HOME}/fish/functions/fish_command_not_found.fish"
      "${XDG_CONFIG_HOME}/fish/conf.d/mise.fish"
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
    # Version resolution lives in _get_mise_target_version: MISE_VERSION env,
    # then get_tool_version (if parse-packages.sh is loaded), then a yq-free
    # read of packages.yaml. The last fallback is what makes first-run work,
    # since yq isn't installed yet at this point.
    _run_mise_installer "Installing mise"

    if ! mise_path=$(command -v mise 2>/dev/null); then
      die "Mise installation failed - binary not found in PATH after installation"
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
  # Skip if already on PATH (idempotent — avoids re-running mise install against
  # the full config.toml on a second call, which triggers spurious warnings for
  # tools whose backends aren't available yet e.g. npm:tree-sitter-cli).
  if [[ -f "${DEVBASE_ROOT}/.mise.toml" ]] && ! command -v yq &>/dev/null; then
    local yq_tool="aqua:mikefarah/yq@v4.52.4"
    show_progress info "Bootstrapping essential tools (yq)..."
    local _bootstrap_err
    if ! _bootstrap_err=$("$mise_path" --no-config use -g "$yq_tool" --yes 2>&1 >/dev/null); then
      [[ -n "$_bootstrap_err" ]] && show_progress error "$_bootstrap_err"
      die "Failed to bootstrap yq via mise"
    fi

    # Activate mise so yq is available on PATH
    _mise_apply_path_from_activate "$mise_path" || die "Failed to activate mise PATH"

    if ! command -v yq &>/dev/null; then
      die "yq not found after mise bootstrap"
    fi

    if ! command -v just &>/dev/null; then
      local just_tool="aqua:casey/just@1.46.0"
      show_progress info "Bootstrapping essential tools (just)..."
      if ! _bootstrap_err=$("$mise_path" --no-config use -g "$just_tool" --yes 2>&1 >/dev/null); then
        [[ -n "$_bootstrap_err" ]] && show_progress warning "$_bootstrap_err"
        add_install_warning "Failed to bootstrap just (continuing)"
      fi
    fi
  fi

  # Generate mise config before activation to avoid stale tool warnings
  # parse-packages.sh performs a hard fail-fast on missing yq, so ensure yq is
  # runnable here as well (the earlier bootstrap can still miss PATH edge cases
  # in non-interactive update/setup flows).
  if ! command -v yq &>/dev/null || ! yq --version >/dev/null 2>&1; then
    show_progress warning "yq unavailable before package parser, attempting recovery"

    local yq_recovery_spec="aqua:mikefarah/yq@v4.52.4"
    local mise_shims="${MISE_DATA_DIR:-${HOME}/.local/share/mise}/shims"
    [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]] && export PATH="${HOME}/.local/bin:${PATH}"
    [[ -d "$mise_shims" && ":${PATH}:" != *":${mise_shims}:"* ]] && export PATH="${mise_shims}:${PATH}"

    "$mise_path" --no-config use -g "$yq_recovery_spec" --yes >/dev/null 2>&1 || true
    _mise_apply_path_from_activate "$mise_path" >/dev/null 2>&1 || true
  fi

  if ! command -v yq &>/dev/null || ! yq --version >/dev/null 2>&1; then
    die "yq not found after bootstrap/recovery"
  fi

  if ! declare -f generate_mise_config &>/dev/null; then
    # shellcheck source=parse-packages.sh
    source "${DEVBASE_LIBS}/parse-packages.sh" || die "Failed to load package parser (is yq installed?)"
  fi

  _setup_package_yaml_env || true

  if [[ -f "$PACKAGES_YAML" ]] && [[ -z "${_DEVBASE_MISE_CONFIG_GENERATED:-}" ]]; then
    local mise_config="${XDG_CONFIG_HOME}/mise/config.toml"
    mkdir -p "$(dirname "$mise_config")"
    generate_mise_config "$mise_config"
    _DEVBASE_MISE_CONFIG_GENERATED=1
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

  # Ensure core runtimes are activated in mise config
  # This avoids "installed but not activated" warnings for selected packs.
  local core_runtime_activation_log="${_DEVBASE_TEMP}/mise-core-activate.log"
  for pack in $DEVBASE_SELECTED_PACKS; do
    local tool=""
    case "$pack" in
    node) tool="node" ;;
    python) tool="python" ;;
    go) tool="go" ;;
    java) tool="java" ;;
    ruby) tool="ruby" ;;
    rust) tool="rust" ;;
    esac
    [[ -z "$tool" ]] && continue

    local version
    version=$(get_tool_version "$tool")
    [[ -z "$version" ]] && continue

    if ! run_mise_from_home_dir which "$tool" &>/dev/null; then
      show_progress info "Activating ${tool}@${version} in mise config"
      if ! run_mise_from_home_dir use -g "${tool}@${version}" &>>"$core_runtime_activation_log"; then
        add_install_warning "Failed to activate ${tool}@${version} in mise config"
        add_install_warning "See log: $core_runtime_activation_log"
      fi
    fi
  done

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
  # `mise prune --tools` deferred to finalize_installation: pruning here
  # would delete the bootstrap yq (orphaned by generate_mise_config) while
  # apply_configurations still has it on PATH and needs it for templates.

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
    else
      show_progress warning "Missing critical development tools: ${missing[*]}"
    fi
    add_install_warning "Missing critical development tools: ${missing[*]}"
    add_install_warning "Install manually with: mise install ${missing[*]}"
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
