#!/usr/bin/env bash

# Brief: Install DevBase color themes to Windows Terminal settings.json (WSL only)
# Params: None
# Uses: DEVBASE_COLORS, command -v, jq (globals/functions)
# Returns: 0 on success/skip, 1 on failure
# Side-effects: Detects Windows username, backs up and modifies Windows Terminal settings.json with theme definitions
install_windows_terminal_themes() {
  # Only run in WSL
  if ! uname -r | grep -qi microsoft; then
    return 0
  fi

  # Check if jq is available
  if ! command -v jq &>/dev/null; then
    printf "  %b✗%b Windows Terminal: jq not available\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    return 1
  fi

  local win_user=""

  # Method 1: Try PowerShell (works in most cases)
  if [[ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]]; then
    win_user=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "Write-Host -NoNewline \$env:USERNAME" 2>/dev/null | tr -d '\r\n')
  fi

  # Method 2: Fallback to cmd.exe
  if [[ -z "$win_user" ]] && [[ -x /mnt/c/Windows/System32/cmd.exe ]]; then
    win_user=$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
  fi

  # Method 3: Fallback to finding real user directory in /mnt/c/Users
  if [[ -z "$win_user" ]] && [[ -d /mnt/c/Users ]]; then
    for user_dir in /mnt/c/Users/*; do
      local dir_name
      dir_name=$(basename "$user_dir")
      # Skip system directories
      if [[ ! "$dir_name" =~ ^(Public|Default|All\ Users|Default\ User)$ ]]; then
        # Check if this user has a Windows Terminal settings file
        if [[ -f "$user_dir/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json" ]] ||
          [[ -f "$user_dir/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json" ]]; then
          win_user="$dir_name"
          break
        fi
      fi
    done
  fi

  # Exit if we couldn't get Windows username
  if [[ -z "$win_user" ]]; then
    printf "  %b✗%b Windows Terminal: Could not detect Windows username\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    return 1
  fi

  # Find Windows Terminal settings path
  local wt_settings=""
  local possible_paths=(
    "/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
    "/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
  )

  for path in "${possible_paths[@]}"; do
    if [[ -f "$path" ]]; then
      wt_settings="$path"
      break
    fi
  done

  # Exit if settings file not found
  if [[ -z "$wt_settings" ]]; then
    printf "  %b✗%b Windows Terminal: settings.json not found for user %s\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" "$win_user" >&2
    return 1
  fi

  # Check if file is writable
  if [[ ! -w "$wt_settings" ]]; then
    printf "  %b✗%b Windows Terminal: settings.json not writable\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    return 1
  fi

  # Find theme files directory
  local theme_dir=""
  # shellcheck disable=SC2153 # XDG_DATA_HOME is set in environment
  local xdg_data_home="${XDG_DATA_HOME}"
  local possible_theme_dirs=(
    "$xdg_data_home/devbase/files/windows-terminal"
    "$HOME/.local/share/devbase/files/windows-terminal"
  )

  for dir in "${possible_theme_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      theme_dir="$dir"
      break
    fi
  done

  # Exit if theme directory not found
  if [[ -z "$theme_dir" ]]; then
    printf "  %b✗%b Windows Terminal: Theme files not found\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    printf "    Expected: %s/devbase/files/windows-terminal/\n" "$xdg_data_home" >&2
    return 1
  fi

  # Create timestamped backup
  local timestamp
  timestamp=$(date +%S.%H.%M.%y)
  local settings_dir
  settings_dir=$(dirname "$wt_settings")
  local backup_file="$settings_dir/settings.$timestamp.json"
  if ! cp "$wt_settings" "$backup_file" 2>/dev/null; then
    printf "  %b✗%b Windows Terminal: Failed to create backup\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    return 1
  fi

  # Load all theme JSON files
  local temp_file
  temp_file=$(mktemp)

  # Theme files to install
  local theme_files=(
    "catppuccin-latte.json"
    "catppuccin-mocha.json"
    "everforest-dark-hard.json"
    "everforest-light-med.json"
    "gruvbox-dark.json"
    "gruvbox-light.json"
    "tokyonight-day.json"
    "tokyonight-night.json"
  )

  # Build themes array
  local themes_array="["
  local first=true
  local theme_count=0
  for theme_file in "${theme_files[@]}"; do
    local theme_path="$theme_dir/$theme_file"
    if [[ -f "$theme_path" ]]; then
      if [[ "$first" == "false" ]]; then
        themes_array="$themes_array,"
      fi
      themes_array="$themes_array$(cat "$theme_path")"
      first=false
      theme_count=$((theme_count + 1))
    fi
  done
  themes_array="$themes_array]"

  # Check if we found any theme files
  if [[ $theme_count -eq 0 ]]; then
    printf "  %b✗%b Windows Terminal: No theme files found in %s\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" "$theme_dir" >&2
    rm -f "$temp_file"
    return 1
  fi

  # Validate themes array is valid JSON
  if ! echo "$themes_array" | jq empty 2>/dev/null; then
    printf "  %b✗%b Windows Terminal: Invalid theme JSON files\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    rm -f "$temp_file"
    return 1
  fi

  # Inject all themes into settings.json
  if jq --argjson themes "$themes_array" 'del(.schemes[]? | select(.name | test("Everforest (Dark Hard|Light Med)|Catppuccin (Mocha|Latte)|TokyoNight (Night|Day)|Gruvbox (Dark|Light)"))) | .schemes += $themes' "$wt_settings" >"$temp_file" 2>&1; then
    # Validate output is valid JSON and non-empty
    if [[ -s "$temp_file" ]] && jq empty "$temp_file" 2>/dev/null; then
      # Use atomic move for safety
      if mv "$temp_file" "$wt_settings" 2>/dev/null; then
        printf "  %b✓%b Windows Terminal: All 8 DevBase themes installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}" >&2
        return 0
      else
        # Restore from backup if move failed
        cp "$backup_file" "$wt_settings" 2>/dev/null
        rm -f "$temp_file"
        printf "  %b✗%b Windows Terminal: Failed to update settings.json\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
        return 1
      fi
    else
      # Invalid JSON produced, cleanup and exit
      printf "  %b✗%b Windows Terminal: Failed to update theme (invalid JSON produced)\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
      rm -f "$temp_file"
      return 1
    fi
  else
    # jq failed, cleanup and exit
    printf "  %b✗%b Windows Terminal: jq command failed\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    rm -f "$temp_file"
    return 1
  fi
}
