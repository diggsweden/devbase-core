#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

# Brief: Detect WSL distro name using multiple methods
# Returns: Echoes distro name to stdout
_detect_wsl_distro() {
  local wsl_distro="${WSL_DISTRO_NAME:-}"
  if [[ -z "$wsl_distro" ]] && [[ -x /mnt/c/Windows/System32/wsl.exe ]]; then
    wsl_distro=$(/mnt/c/Windows/System32/wsl.exe -l -v 2>/dev/null |
      grep -E '^\*' |
      awk '{print $2}' |
      tr -d '\r' ||
      echo "")
  fi
  if [[ -z "$wsl_distro" ]]; then
    wsl_distro=$(grep -oP '(?<=^NAME=").+(?=")' /etc/os-release 2>/dev/null || echo "Ubuntu")
  fi
  echo "$wsl_distro"
}

# Brief: Find Windows VSCode installation path
# Returns: 0 and echoes path if found, 1 otherwise
_find_windows_vscode() {
  if [[ -f "/mnt/c/Program Files/Microsoft VS Code/bin/code" ]]; then
    echo "/mnt/c/Program Files/Microsoft VS Code/bin/code"
    return 0
  fi
  return 1
}

# Brief: Install Remote-WSL extension on Windows VSCode
# Params: $1 - Windows VSCode command path
# Returns: 0 always
_install_remote_wsl_extension() {
  local win_code_cmd="$1"

  if [[ -z "${WSL_INTEROP:-}" ]]; then
    return 0
  fi

  if "$win_code_cmd" --list-extensions 2>/dev/null | grep -qi "ms-vscode-remote.remote-wsl"; then
    return 0
  fi

  show_progress info "[WSL-specific] Installing Remote-WSL extension on Windows VSCode..."

  if NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt "$win_code_cmd" --install-extension ms-vscode-remote.remote-wsl --force; then
    show_progress success "[WSL-specific] Remote-WSL extension installed on Windows VSCode"
  else
    show_progress warning "[WSL-specific] Could not auto-install Remote-WSL extension"
  fi

  return 0
}

# Brief: Find VSCode Server CLI path
# Returns: 0 and echoes path if found, 1 otherwise
_find_vscode_server_cli() {
  validate_var_set "HOME" || return 1

  if [[ ! -d "$HOME/.vscode-server/bin" ]]; then
    return 1
  fi

  local vscode_server_path
  vscode_server_path=$(find "$HOME/.vscode-server/bin/" -maxdepth 2 -path "*/bin/remote-cli/code" -type f 2>/dev/null | sort -r | head -1)

  if [[ -n "$vscode_server_path" ]] && [[ -f "$vscode_server_path" ]]; then
    if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
      echo "$vscode_server_path"
      return 0
    fi
  fi

  return 1
}

# Brief: Setup code command for WSL environment
# Params: $1 - Windows code command (if available)
# Returns: Echoes "code_command remote_flag" to stdout
_setup_wsl_code_command() {
  local win_code_cmd="$1"
  local code_command=""
  local remote_flag=""

  if [[ -d "$HOME/.vscode-server/bin" ]]; then
    show_progress success "[WSL-specific] VS Code Server detected" >&2

    if [[ -n "$win_code_cmd" ]] && [[ -n "${WSL_INTEROP:-}" ]]; then
      code_command="$win_code_cmd"
      remote_flag=""
    else
      local vscode_server_path
      if vscode_server_path=$(_find_vscode_server_cli); then
        code_command="$vscode_server_path"
        show_progress info "[WSL-specific] Using VS Code Server CLI" >&2
      fi
      # If no code_command available, we'll handle messaging in the main function
    fi
  else
    if [[ -n "$win_code_cmd" ]]; then
      show_progress info "[WSL-specific] VS Code Server not found - extensions will be installed after first connection" >&2
    fi
  fi

  echo "$code_command"
  echo "$remote_flag"
}

# Brief: Find native VSCode command (non-WSL)
# Returns: 0 and echoes path if found, 1 otherwise
_find_native_vscode() {
  if [[ -x /usr/bin/code ]]; then
    echo "/usr/bin/code"
    return 0
  elif [[ -x /usr/local/bin/code ]]; then
    echo "/usr/local/bin/code"
    return 0
  elif command -v code &>/dev/null; then
    echo "code"
    return 0
  fi
  return 1
}

# Brief: Main VS Code setup including WSL detection and extension installation
# Params: None
# Uses: DEVBASE_VSCODE_EXTENSIONS, DEVBASE_VSCODE_NEOVIM, DEVBASE_DOT, HOME, is_wsl, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Installs Remote-WSL extension, configures VS Code settings, installs extensions or creates installer script
setup_vscode() {
  validate_var_set "HOME" || return 1
  validate_var_set "DEVBASE_DOT" || return 1

  show_progress info "Setting up VS Code extensions..."

  local code_command=""
  local remote_flag=""

  if is_wsl; then
    local wsl_distro
    wsl_distro=$(_detect_wsl_distro)

    local win_code_cmd=""
    if win_code_cmd=$(_find_windows_vscode); then
      _install_remote_wsl_extension "$win_code_cmd"
    fi

    local wsl_setup
    wsl_setup=$(_setup_wsl_code_command "$win_code_cmd")
    code_command=$(echo "$wsl_setup" | sed -n '1p')
    remote_flag=$(echo "$wsl_setup" | sed -n '2p')
  else
    if code_command=$(_find_native_vscode); then
      : # code_command already set
    fi
  fi

  printf "\n"
  if [[ "${DEVBASE_VSCODE_EXTENSIONS}" == "true" ]]; then
    if [[ -n "$code_command" ]]; then
      show_progress info "Installing VS Code extensions..."
      install_vscode_extensions "$code_command" "$remote_flag"
    else
      # VS Code Server exists but CLI not available (e.g., su -l without active VS Code connection)
      if is_wsl && [[ -d "$HOME/.vscode-server/bin" ]]; then
        show_progress info "VS Code Server detected but not currently connected"
        show_progress info "Extensions will be installed automatically when you open VS Code and connect to WSL"
      else
        show_progress info "VS Code not detected - skipping extension installation"
        if is_wsl; then
          show_progress info "Extensions will be installed after connecting VS Code to WSL"
        fi
      fi
    fi

    configure_vscode_settings

    show_progress success "VS Code setup completed"
  else
    show_progress info "Skipping VS Code extensions"
    export DEVBASE_VSCODE_NEOVIM="false"
  fi

  return 0
}

# Brief: Configure VS Code settings.json with theme and optional Neovim integration
# Params: None
# Uses: DEVBASE_VSCODE_NEOVIM, DEVBASE_THEME, DEVBASE_DOT, HOME, show_progress (globals/functions)
# Returns: 0 always
# Side-effects: Backs up existing settings, merges or creates settings.json in VS Code config directory
_get_vscode_settings_dir() {
  if [[ -d "$HOME/.vscode-server/data/Machine" ]]; then
    echo "$HOME/.vscode-server/data/Machine"
    return 0
  elif [[ -d "$HOME/.config/Code/User" ]]; then
    echo "$HOME/.config/Code/User"
    return 0
  elif [[ -d "$HOME/.vscode-server" ]]; then
    local dir="$HOME/.vscode-server/data/Machine"
    mkdir -p "$dir"
    echo "$dir"
    return 0
  fi
  return 1
}

_get_vscode_theme_name() {
  local theme="${1:-everforest-dark}"
  case "$theme" in
  everforest-dark) echo "Everforest Dark" ;;
  everforest-light) echo "Everforest Light" ;;
  catppuccin-mocha) echo "Catppuccin Mocha" ;;
  catppuccin-latte) echo "Catppuccin Latte" ;;
  tokyonight-night) echo "Tokyo Night" ;;
  tokyonight-day) echo "Tokyo Night Light" ;;
  gruvbox-dark) echo "Gruvbox Dark Medium" ;;
  gruvbox-light) echo "Gruvbox Light Medium" ;;
  nord) echo "Nord" ;;
  dracula) echo "Dracula Theme" ;;
  solarized-dark) echo "Solarized Dark+" ;;
  solarized-light) echo "Solarized Light+" ;;
  *) echo "Everforest Dark" ;;
  esac
}

_backup_vscode_settings() {
  local settings_file="$1"
  if [[ -f "$settings_file" ]]; then
    local backup_file="${settings_file}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$settings_file" "$backup_file"
    show_progress info "Backed up existing settings to $backup_file"
    return 0
  fi
  return 1
}

_merge_vscode_settings_jq() {
  local settings_target="$1"
  local vscode_theme="$2"
  local configure_neovim="$3"
  local settings_template="$4"

  local new_settings='{"workbench.colorTheme": "'$vscode_theme'"}'

  if [[ "$configure_neovim" == "true" ]]; then
    new_settings=$(jq -s '.[0] * .[1]' <(echo "$new_settings") "$settings_template")
  fi

  echo "$new_settings" | jq -s '.[0] * .[1]' "$settings_target" - >"${settings_target}.tmp"
  mv "${settings_target}.tmp" "$settings_target"
}

_merge_vscode_settings_manual() {
  local settings_target="$1"
  local settings_template="$2"
  local existing_settings="$3"

  local new_settings
  new_settings=$(grep -Ev '^[{}]' "$settings_template")

  if echo "$existing_settings" | grep -q '".*":'; then
    echo "${existing_settings%\}}" >"$settings_target"
    echo ",${new_settings}" >>"$settings_target"
    echo "}" >>"$settings_target"
  else
    cp "$settings_template" "$settings_target"
  fi
}

_create_new_vscode_settings_jq() {
  local settings_target="$1"
  local vscode_theme="$2"
  local configure_neovim="$3"
  local settings_template="$4"

  if [[ "$configure_neovim" == "true" ]]; then
    jq --arg theme "$vscode_theme" '. + {"workbench.colorTheme": $theme}' "$settings_template" >"$settings_target"
  else
    echo '{"workbench.colorTheme": "'"$vscode_theme"'"}' | jq '.' >"$settings_target"
  fi
}

_create_new_vscode_settings_manual() {
  local settings_target="$1"
  local vscode_theme="$2"
  local configure_neovim="$3"
  local settings_template="$4"

  if [[ "$configure_neovim" == "true" ]]; then
    cp "$settings_template" "$settings_target"
    local content
    content=$(cat "$settings_target")
    echo "${content%\}}" >"$settings_target"
    echo ",  \"workbench.colorTheme\": \"$vscode_theme\"" >>"$settings_target"
    echo "}" >>"$settings_target"
  else
    echo '{
  "workbench.colorTheme": "'"$vscode_theme"'"
}' >"$settings_target"
  fi
}

configure_vscode_settings() {
  validate_var_set "DEVBASE_DOT" || return 1
  validate_var_set "HOME" || return 1

  show_progress info "Configuring VS Code settings..."

  local configure_neovim="${DEVBASE_VSCODE_NEOVIM}"
  # shellcheck disable=SC2153  # DEVBASE_DOT is exported in setup.sh
  local settings_template="${DEVBASE_DOT}/.config/vscode/settings.json"

  # Get settings directory
  local vscode_settings_dir
  if ! vscode_settings_dir=$(_get_vscode_settings_dir); then
    show_progress info "VS Code settings directory not found, skipping configuration"
    return 0
  fi

  local settings_target="$vscode_settings_dir/settings.json"
  local vscode_theme
  vscode_theme=$(_get_vscode_theme_name "${DEVBASE_THEME}")

  # Validate template
  if [[ ! -f "$settings_template" ]]; then
    show_progress warning "VS Code settings template not found at $settings_template"
    return 0
  fi

  # Handle existing settings file
  if [[ -f "$settings_target" ]]; then
    _backup_vscode_settings "$settings_target"

    show_progress info "Merging VS Code settings..."

    local existing_settings
    existing_settings=$(cat "$settings_target")

    # Skip if neovim already configured
    if echo "$existing_settings" | grep -q "vscode-neovim"; then
      show_progress info "Neovim settings already configured, skipping"
      return 0
    fi

    # Merge settings
    if command -v jq &>/dev/null; then
      _merge_vscode_settings_jq "$settings_target" "$vscode_theme" "$configure_neovim" "$settings_template"
      show_progress success "VS Code settings merged successfully"
    else
      _merge_vscode_settings_manual "$settings_target" "$settings_template" "$existing_settings"
      show_progress success "VS Code settings updated"
    fi
  else
    # Create new settings file
    if command -v jq &>/dev/null; then
      _create_new_vscode_settings_jq "$settings_target" "$vscode_theme" "$configure_neovim" "$settings_template"
    else
      _create_new_vscode_settings_manual "$settings_target" "$vscode_theme" "$configure_neovim" "$settings_template"
    fi
    show_progress success "VS Code settings configured with theme: $vscode_theme"
  fi

  return 0
}

# Brief: Get human-readable description for VS Code extension ID
# Params: $1 - extension ID (e.g., "esbenp.prettier-vscode")
# Returns: Echoes description string to stdout, empty string if unknown
get_extension_description() {
  local ext_id="$1"

  validate_not_empty "$ext_id" "Extension ID" || return 1

  case "$ext_id" in
  "asciidoctor.asciidoctor-vscode") echo "AsciiDoc language support" ;;
  "bradlc.vscode-tailwindcss") echo "Tailwind CSS IntelliSense" ;;
  "dbaeumer.vscode-eslint") echo "ESLint JavaScript/TypeScript linter" ;;
  "esbenp.prettier-vscode") echo "Prettier code formatter" ;;
  "lokalise.i18n-ally") echo "i18n internationalization manager" ;;
  "pkief.material-icon-theme") echo "Material Icon Theme" ;;
  "sainnhe.everforest") echo "Everforest color theme" ;;
  "catppuccin.catppuccin-vsc") echo "Catppuccin color theme" ;;
  "enkia.tokyo-night") echo "Tokyo Night color theme" ;;
  "jdinhlife.gruvbox") echo "Gruvbox color theme" ;;
  "redhat.java") echo "Java language support" ;;
  "redhat.vscode-yaml") echo "YAML language support" ;;
  "shengchen.vscode-checkstyle") echo "Checkstyle Java code style" ;;
  "sonarsource.sonarlint-vscode") echo "SonarLint code quality analyzer" ;;
  "vscjava.vscode-java-debug") echo "Java debugger" ;;
  "vscjava.vscode-java-dependency") echo "Java dependency viewer" ;;
  "vscjava.vscode-java-test") echo "Java test runner" ;;
  "vscjava.vscode-maven") echo "Maven build tool support" ;;
  "vscjava.vscode-java-pack") echo "Java Extension Pack" ;;
  "vue.volar") echo "Vue.js language support" ;;
  "asvetliakov.vscode-neovim") echo "Neovim integration" ;;
  "MS-SarifVSCode.sarif-viewer") echo "SARIF static analysis viewer" ;;
  *) echo "" ;;
  esac
}

# Brief: Find extensions file (default or custom)
# Returns: echoes file path to stdout, returns 1 if not found
_install_vscode_ext_find_file() {
  validate_var_set "DEVBASE_DOT" || return 1

  local extensions_file="${DEVBASE_DOT}/.config/devbase/vscode-extensions.yaml"

  if [[ -n "${_DEVBASE_CUSTOM_PACKAGES}" ]] && [[ -f "${_DEVBASE_CUSTOM_PACKAGES}/vscode-extensions.yaml" ]]; then
    extensions_file="${_DEVBASE_CUSTOM_PACKAGES}/vscode-extensions.yaml"
    show_progress info "Using custom VSCode extensions list: $extensions_file"
  fi

  validate_file_exists "$extensions_file" "vscode-extensions.yaml" || return 1
  echo "$extensions_file"
}

# Brief: Test VS Code command availability
# Params: $1-code_cmd $2-remote_flag
# Returns: 0 if working, 1 if failed
_install_vscode_ext_test_command() {
  local code_cmd="$1"
  local remote_flag="$2"

  # Skip version test if using --remote flag since it would open GUI
  [[ -n "$remote_flag" ]] && return 0

  local test_output
  if ! test_output=$("$code_cmd" --version 2>&1); then
    show_progress error "VS Code command failed: $code_cmd"
    echo "Error output: $test_output" >&2
    return 1
  fi
  return 0
}

# Brief: Get list of already-installed extensions
# Params: $1-code_cmd $2-remote_flag
# Returns: echoes extension list to stdout
_install_vscode_ext_get_installed() {
  local code_cmd="$1"
  local remote_flag="$2"

  if [[ -n "$remote_flag" ]]; then
    "$code_cmd" "$remote_flag" --list-extensions 2>/dev/null || true
  else
    "$code_cmd" --list-extensions 2>/dev/null || true
  fi
}

# Brief: Parse and normalize extension ID from YAML line
# Params: $1-raw extension ID string
# Returns: echoes trimmed ID to stdout, returns 1 if empty/comment
_install_vscode_ext_parse_id() {
  local raw_id="$1"

  # Skip comments and empty lines
  [[ "$raw_id" =~ ^[[:space:]]*# ]] && return 1
  [[ -z "$raw_id" ]] && return 1

  # Trim whitespace
  local trimmed
  trimmed=$(echo "$raw_id" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [[ -z "$trimmed" ]] && return 1

  echo "$trimmed"
}

# Brief: Build display name for extension
# Params: $1-ext_id
# Returns: echoes display name to stdout
_install_vscode_ext_display_name() {
  local ext_id="$1"
  local ext_desc
  ext_desc=$(get_extension_description "$ext_id")

  if [[ -n "$ext_desc" ]]; then
    echo "${ext_desc} (${ext_id})"
  else
    echo "$ext_id"
  fi
}

# Brief: Install single extension
# Params: $1-code_cmd $2-remote_flag $3-ext_id $4-display_name $5-installed_list
# Returns: 0=installed, 1=failed, 2=skipped
_install_vscode_ext_install_one() {
  local code_cmd="$1"
  local remote_flag="$2"
  local ext_id="$3"
  local display_name="$4"
  local installed_list="$5"

  # Skip neovim extension if user opted out
  if [[ "$ext_id" == "asvetliakov.vscode-neovim" ]] && [[ "${DEVBASE_VSCODE_NEOVIM}" != "true" ]]; then
    show_progress info "$display_name (skipped by user preference)"
    return 2
  fi

  # Check if already installed
  if echo "$installed_list" | grep -qi "^${ext_id}$"; then
    show_progress info "$display_name (already installed)"
    return 2
  fi

  # Install extension
  local install_args=("--install-extension" "$ext_id" "--force")
  [[ -n "$remote_flag" ]] && install_args=("$remote_flag" "${install_args[@]}")

  if NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt "$code_cmd" "${install_args[@]}"; then
    show_progress success "$display_name"
    return 0
  else
    show_progress error "Failed: $display_name"
    return 1
  fi
}

# Brief: Print installation summary
# Params: $1-installed_count $2-skipped_count $3-failed_count $4-failed_extensions_array_name
# Returns: always 0
_install_vscode_ext_print_summary() {
  local installed_count="$1"
  local skipped_count="$2"
  local failed_count="$3"
  local -n failed_ext_list=$4

  [[ $installed_count -gt 0 ]] && show_progress success "Installed $installed_count extensions"
  [[ $skipped_count -gt 0 ]] && show_progress info "$skipped_count extensions already installed"

  if [[ $failed_count -gt 0 ]]; then
    show_progress warning "$failed_count extensions failed to install:"
    for ext in "${failed_ext_list[@]}"; do
      printf "    • %s\n" "$ext"
    done
  fi

  show_progress success "VS Code setup complete"
}

# Brief: Install VS Code extensions from vscode-extensions.yaml
# Params: $1 - code_cmd (path to code executable), $2 - remote_flag (optional)
# Uses: DEVBASE_DOT, DEVBASE_VSCODE_NEOVIM, _DEVBASE_CUSTOM_PACKAGES, get_extension_description, show_progress (globals/functions)
# Returns: 0 on success, 1 if code_cmd fails or vscode-extensions.yaml not found
# Side-effects: Installs VS Code extensions, prints installation summary
install_vscode_extensions() {
  local code_cmd="$1"
  local remote_flag="$2"

  validate_not_empty "$code_cmd" "VS Code command" || return 1

  local extensions_file
  extensions_file=$(_install_vscode_ext_find_file) || return 1

  _install_vscode_ext_test_command "$code_cmd" "$remote_flag" || return 1

  local installed_list
  installed_list=$(_install_vscode_ext_get_installed "$code_cmd" "$remote_flag")

  local installed_count=0
  local skipped_count=0
  local failed_count=0
  local failed_extensions=()

  while IFS=: read -r ext_id version_line; do
    local parsed_id
    parsed_id=$(_install_vscode_ext_parse_id "$ext_id") || continue

    local display_name
    display_name=$(_install_vscode_ext_display_name "$parsed_id")

    local result
    _install_vscode_ext_install_one "$code_cmd" "$remote_flag" "$parsed_id" "$display_name" "$installed_list"
    result=$?

    case $result in
    0) installed_count=$((installed_count + 1)) ;;
    1)
      failed_count=$((failed_count + 1))
      failed_extensions+=("$parsed_id")
      ;;
    2) skipped_count=$((skipped_count + 1)) ;;
    esac
  done <"$extensions_file"

  _install_vscode_ext_print_summary $installed_count $skipped_count $failed_count failed_extensions
  return 0
}
