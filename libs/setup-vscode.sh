#!/usr/bin/env bash
set -uo pipefail

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  # shellcheck disable=SC2317 # Handles both sourced and executed contexts
  return 1 2>/dev/null || exit 1
fi

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
    # Get WSL distro name - try multiple methods
    local wsl_distro="${WSL_DISTRO_NAME:-}"
    if [[ -z "$wsl_distro" ]] && [[ -x /mnt/c/Windows/System32/wsl.exe ]]; then
      # Query from wsl.exe which distro we're running in
      # Extract the default distro (line starting with *)
      wsl_distro=$(/mnt/c/Windows/System32/wsl.exe -l -v 2>/dev/null |
        grep -E '^\*' |    # Find line with asterisk (default distro)
        awk '{print $2}' | # Get distro name (second field)
        tr -d '\r' ||      # Remove Windows carriage return
        echo "")
    fi
    if [[ -z "$wsl_distro" ]]; then
      # Fallback to OS name
      wsl_distro=$(grep -oP '(?<=^NAME=").+(?=")' /etc/os-release 2>/dev/null || echo "Ubuntu")
    fi

    # Check for Windows VSCode
    local win_code_cmd=""

    if [[ -f "/mnt/c/Program Files/Microsoft VS Code/bin/code" ]]; then
      win_code_cmd="/mnt/c/Program Files/Microsoft VS Code/bin/code"
    fi

    # If Windows VSCode found, install Remote-WSL extension on Windows side

    if [[ -n "$win_code_cmd" ]]; then
      # Check if WSL_INTEROP is set (needed to run Windows executables)
      if [[ -n "${WSL_INTEROP:-}" ]]; then
        # Check if Remote-WSL extension is already installed
        if ! "$win_code_cmd" --list-extensions 2>/dev/null | grep -qi "ms-vscode-remote.remote-wsl"; then
          # Try to install Remote-WSL extension on Windows VSCode
          show_progress info "[WSL-specific] Installing Remote-WSL extension on Windows VSCode..."

          if NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt "$win_code_cmd" --install-extension ms-vscode-remote.remote-wsl --force; then
            show_progress success "[WSL-specific] Remote-WSL extension installed on Windows VSCode"
          else
            show_progress warning "[WSL-specific] Could not auto-install Remote-WSL extension"
          fi
        fi
      fi
    fi

    # Now set up code command for WSL
    if [[ -d "$HOME/.vscode-server/bin" ]]; then
      # vscode-server exists - we can install extensions
      show_progress success "[WSL-specific] VS Code Server detected"

      if [[ -n "$win_code_cmd" ]] && [[ -n "${WSL_INTEROP:-}" ]]; then
        # Use Windows code.exe - it auto-detects WSL context when called from within WSL
        # The --remote flag is for calling FROM Windows TO WSL, not from within WSL
        code_command="$win_code_cmd"
        remote_flag=""
      else
        # Try to find vscode-server CLI directly
        local vscode_server_path
        vscode_server_path=$(find "$HOME/.vscode-server/bin/" -maxdepth 2 -path "*/bin/remote-cli/code" -type f 2>/dev/null | sort -r | head -1)

        if [[ -n "$vscode_server_path" ]] && [[ -f "$vscode_server_path" ]]; then
          # VS Code Server CLI only works inside an active VS Code terminal
          # Check if we're in a VS Code terminal by looking for TERM_PROGRAM
          if [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
            code_command="$vscode_server_path"
            show_progress info "[WSL-specific] Using VS Code Server CLI"
          else
            show_progress warning "[WSL-specific] VS Code Server CLI requires active VS Code connection"
            show_progress info "[WSL-specific] Extensions will be installed after connecting VS Code"
          fi
        else
          show_progress warning "[WSL-specific] VS Code Server found but CLI not available"
        fi
      fi
    else
      # No vscode-server yet
      if [[ -n "$win_code_cmd" ]]; then
        show_progress info "[WSL-specific] VS Code Server not found - extensions will be installed after first connection"
      fi
    fi
  else
    # Not WSL - check for native code command
    # Try multiple locations where code might be installed
    if [[ -x /usr/bin/code ]]; then
      code_command="/usr/bin/code"
    elif [[ -x /usr/local/bin/code ]]; then
      code_command="/usr/local/bin/code"
    elif command -v code &>/dev/null; then
      code_command="code"
    fi
  fi # End of is_wsl block

  printf "\n"
  if [[ "${DEVBASE_VSCODE_EXTENSIONS}" == "true" ]]; then
    show_progress info "Installing VS Code extensions..."

    if [[ -n "$code_command" ]]; then
      install_vscode_extensions "$code_command" "$remote_flag"
    else
      # No code command available - skip extension installation
      show_progress info "VS Code command not available - skipping extensions"
      show_progress info "Install VS Code and connect to WSL to install extensions"
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
configure_vscode_settings() {
  validate_var_set "DEVBASE_DOT" || return 1
  validate_var_set "HOME" || return 1

  show_progress info "Configuring VS Code settings..."

  local configure_neovim="${DEVBASE_VSCODE_NEOVIM}"

  # shellcheck disable=SC2153 # DEVBASE_DOT is set in setup.sh
  local settings_template="${DEVBASE_DOT}/.config/vscode/settings.json"
  local vscode_settings_dir=""
  local settings_target=""

  # Determine settings location based on installation type
  if [[ -d "$HOME/.vscode-server/data/Machine" ]]; then
    # WSL with VS Code Server
    vscode_settings_dir="$HOME/.vscode-server/data/Machine"
    settings_target="$vscode_settings_dir/settings.json"
  elif [[ -d "$HOME/.config/Code/User" ]]; then
    # Native Linux VS Code
    vscode_settings_dir="$HOME/.config/Code/User"
    settings_target="$vscode_settings_dir/settings.json"
  elif [[ -d "$HOME/.vscode-server" ]]; then
    # WSL but Machine folder doesn't exist yet
    vscode_settings_dir="$HOME/.vscode-server/data/Machine"
    settings_target="$vscode_settings_dir/settings.json"
    mkdir -p "$vscode_settings_dir"
  else
    show_progress info "VS Code settings directory not found, skipping configuration"
    return 0
  fi

  # Map DEVBASE_THEME to VSCode theme name
  local vscode_theme="Everforest Dark" # default
  if [[ -n "${DEVBASE_THEME}" ]]; then
    case "${DEVBASE_THEME}" in
    everforest-dark)
      vscode_theme="Everforest Dark"
      ;;
    everforest-light)
      vscode_theme="Everforest Light"
      ;;
    catppuccin-mocha)
      vscode_theme="Catppuccin Mocha"
      ;;
    catppuccin-latte)
      vscode_theme="Catppuccin Latte"
      ;;
    tokyonight-night)
      vscode_theme="Tokyo Night"
      ;;
    tokyonight-day)
      vscode_theme="Tokyo Night Light"
      ;;
    gruvbox-dark)
      vscode_theme="Gruvbox Dark Medium"
      ;;
    gruvbox-light)
      vscode_theme="Gruvbox Light Medium"
      ;;
    esac
  fi

  # Check if template exists
  if [[ ! -f "$settings_template" ]]; then
    show_progress warning "VS Code settings template not found at $settings_template"
    return 0
  fi

  # Backup existing settings if present
  if [[ -f "$settings_target" ]]; then
    local backup_file
    backup_file="$settings_target.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$settings_target" "$backup_file"
    show_progress info "Backed up existing settings to $backup_file"

    # Merge settings instead of overwriting
    show_progress info "Merging VS Code settings..."

    # Read existing settings
    local existing_settings
    existing_settings=$(cat "$settings_target")

    # Check if neovim settings already exist
    if echo "$existing_settings" | grep -q "vscode-neovim"; then
      show_progress info "Neovim settings already configured, skipping"
      return 0
    fi

    # Merge the settings using jq if available, otherwise manual merge
    if command -v jq &>/dev/null; then
      # Build settings based on user preferences
      local new_settings='{"workbench.colorTheme": "'$vscode_theme'"}'

      if [[ "$configure_neovim" == "true" ]]; then
        # Add neovim settings from template
        new_settings=$(jq -s '.[0] * .[1]' <(echo "$new_settings") "$settings_template")
      fi

      # Merge with existing settings
      echo "$new_settings" | jq -s '.[0] * .[1]' "$settings_target" - >"${settings_target}.tmp"
      mv "${settings_target}.tmp" "$settings_target"
      show_progress success "VS Code settings merged successfully"
    else
      # Manual merge - add neovim settings before the closing brace
      # Extract content from template (without opening/closing braces)
      local new_settings
      new_settings=$(grep -Ev '^[{}]' "$settings_template")
      # Remove trailing } from existing, add comma if needed, append new settings
      if echo "$existing_settings" | grep -q '".*":'; then
        # Has existing settings, need comma
        echo "${existing_settings%\}}" >"$settings_target"
        echo ",${new_settings}" >>"$settings_target"
        echo "}" >>"$settings_target"
      else
        # Empty or just {}, replace entirely
        cp "$settings_template" "$settings_target"
      fi
      show_progress success "VS Code settings updated"
    fi
  else
    # No existing settings, create new with appropriate content
    if command -v jq &>/dev/null; then
      local new_settings='{"workbench.colorTheme": "'$vscode_theme'"}'

      if [[ "$configure_neovim" == "true" ]]; then
        # Add neovim settings from template
        jq --arg theme "$vscode_theme" '. + {"workbench.colorTheme": $theme}' "$settings_template" >"$settings_target"
      else
        # Just theme, no neovim
        echo "$new_settings" | jq '.' >"$settings_target"
      fi
    else
      if [[ "$configure_neovim" == "true" ]]; then
        cp "$settings_template" "$settings_target"
        # Add theme manually
        local content
        content=$(cat "$settings_target")
        echo "${content%\}}" >"$settings_target"
        echo ",  \"workbench.colorTheme\": \"$vscode_theme\"" >>"$settings_target"
        echo "}" >>"$settings_target"
      else
        # Just create with theme
        echo '{
  "workbench.colorTheme": "'"$vscode_theme"'"
}' >"$settings_target"
      fi
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

# Brief: Install VS Code extensions from vscode-extensions.yaml
# Params: $1 - code_cmd (path to code executable), $2 - remote_flag (optional)
# Uses: DEVBASE_DOT, DEVBASE_VSCODE_NEOVIM, get_extension_description, show_progress (globals/functions)
# Returns: 0 on success, 1 if code_cmd fails or vscode-extensions.yaml not found
# Side-effects: Installs VS Code extensions, prints installation summary
install_vscode_extensions() {
  local code_cmd="$1"
  local remote_flag="$2"

  validate_not_empty "$code_cmd" "VS Code command" || return 1
  validate_var_set "DEVBASE_DOT" || return 1

  local extensions_file="${DEVBASE_DOT}/.config/devbase/vscode-extensions.yaml"

  validate_file_exists "$extensions_file" "vscode-extensions.yaml" || return 1

  # Skip version test if using --remote flag since it would open GUI
  if [[ -z "$remote_flag" ]]; then
    local test_output
    if ! test_output=$("$code_cmd" --version 2>&1); then
      show_progress error "VS Code command failed: $code_cmd"
      echo "Error output: $test_output" >&2
      return 1
    fi
  fi

  local installed_count=0
  local skipped_count=0
  local failed_count=0
  local failed_extensions=()

  local installed_list
  if [[ -n "$remote_flag" ]]; then
    installed_list=$("$code_cmd" "$remote_flag" --list-extensions 2>/dev/null || true)
  else
    installed_list=$("$code_cmd" --list-extensions 2>/dev/null || true)
  fi

  while IFS=: read -r ext_id version_line; do
    # Skip comments and empty lines
    [[ "$ext_id" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$ext_id" ]] && continue

    # Trim leading/trailing whitespace from extension ID
    ext_id=$(echo "$ext_id" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Skip if still empty after trimming
    [[ -z "$ext_id" ]] && continue

    local ext_desc
    ext_desc=$(get_extension_description "$ext_id")
    local display_name="$ext_id"
    if [[ -n "$ext_desc" ]]; then
      display_name="${ext_desc} (${ext_id})"
    fi

    # Skip neovim extension if user opted out
    if [[ "$ext_id" == "asvetliakov.vscode-neovim" ]] && [[ "${DEVBASE_VSCODE_NEOVIM}" != "true" ]]; then
      show_progress info "$display_name (skipped by user preference)"
      continue
    fi

    if echo "$installed_list" | grep -qi "^${ext_id}$"; then
      show_progress info "$display_name (already installed)"
      skipped_count=$((skipped_count + 1))
    else
      if [[ -n "$remote_flag" ]]; then
        if NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt "$code_cmd" "$remote_flag" --install-extension "$ext_id" --force; then
          show_progress success "$display_name"
          installed_count=$((installed_count + 1))
        else
          show_progress error "Failed: $display_name"
          failed_count=$((failed_count + 1))
          failed_extensions+=("$ext_id")
        fi
      else
        if NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt "$code_cmd" --install-extension "$ext_id" --force; then
          show_progress success "$display_name"
          installed_count=$((installed_count + 1))
        else
          show_progress error "Failed: $display_name"
          failed_count=$((failed_count + 1))
          failed_extensions+=("$ext_id")
        fi
      fi
    fi
  done <"$extensions_file"

  if [[ $installed_count -gt 0 ]]; then
    show_progress success "Installed $installed_count extensions"
  fi
  if [[ $skipped_count -gt 0 ]]; then
    show_progress info "$skipped_count extensions already installed"
  fi
  if [[ $failed_count -gt 0 ]]; then
    show_progress warning "$failed_count extensions failed to install:"
    for ext in "${failed_extensions[@]}"; do
      printf "    • %s\n" "$ext"
    done
  fi

  show_progress success "VS Code setup complete"
  return 0
}
