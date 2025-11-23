#!/usr/bin/env bash
set -uo pipefail

# Brief: Detect Windows username using multiple methods
# Params: None
# Returns: 0 on success, 1 on failure
# Outputs: Windows username to stdout
_detect_windows_username() {
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

  # Return username or failure
  if [[ -z "$win_user" ]]; then
    return 1
  fi

  echo "$win_user"
  return 0
}

# Brief: Find Windows Terminal settings.json path
# Params: $1 - Windows username
# Returns: 0 on success, 1 on failure
# Outputs: Path to settings.json to stdout
_find_wt_settings_path() {
  local win_user="$1"
  local possible_paths=(
    "/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
    "/mnt/c/Users/$win_user/AppData/Local/Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json"
  )

  for path in "${possible_paths[@]}"; do
    if [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done

  return 1
}

# Brief: Find Windows Terminal theme files directory
# Params: None
# Returns: 0 on success, 1 on failure
# Outputs: Path to theme directory to stdout
_find_wt_theme_directory() {
  validate_var_set "XDG_DATA_HOME" || return 1
  # shellcheck disable=SC2153 # XDG_DATA_HOME validated above, exported in setup.sh
  local xdg_data_home="${XDG_DATA_HOME}"
  local possible_theme_dirs=(
    "$xdg_data_home/devbase/files/windows-terminal"
    "$HOME/.local/share/devbase/files/windows-terminal"
  )

  for dir in "${possible_theme_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      echo "$dir"
      return 0
    fi
  done

  return 1
}

# Brief: Build JSON array of all theme files
# Params: $1 - Theme directory path
# Returns: 0 on success, 1 on failure
# Outputs: JSON array to stdout, theme count to stderr
_build_themes_json_array() {
  local theme_dir="$1"
  local theme_files=(
    "catppuccin-latte.json"
    "catppuccin-mocha.json"
    "dracula.json"
    "everforest-dark-hard.json"
    "everforest-light-med.json"
    "gruvbox-dark.json"
    "gruvbox-light.json"
    "nord.json"
    "tokyonight-day.json"
    "tokyonight-night.json"
  )

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

  # Output count to stderr for caller
  echo "$theme_count" >&2
  # Output JSON to stdout
  echo "$themes_array"
  return 0
}

# Brief: Inject themes into Windows Terminal settings.json
# Params: $1 - Settings file path, $2 - Themes JSON array, $3 - Backup file path
# Returns: 0 on success, 1 on failure
_inject_themes_to_settings() {
  local wt_settings="$1"
  local themes_array="$2"
  local backup_file="$3"
  local temp_file
  temp_file=$(mktemp)

  # shellcheck disable=SC2016 # $themes is a jq variable, not a shell variable
  local jq_filter='
    .[0] as $themes
    | .[1]
    | del(.schemes[]? | select(.name | test("Everforest (Dark Hard|Light Med)|Catppuccin (Mocha|Latte)|TokyoNight (Night|Day)|Gruvbox (Dark|Light)|Nord|Dracula|Solarized (Dark|Light)")))
    | .schemes += $themes
  '

  if echo "$themes_array" | jq -s "$jq_filter" - "$wt_settings" >"$temp_file" 2>&1; then
    # Validate output is valid JSON and non-empty
    if [[ -s "$temp_file" ]] && jq empty "$temp_file" 2>/dev/null; then
      # Use atomic move for safety
      if mv "$temp_file" "$wt_settings" 2>/dev/null; then
        return 0
      else
        # Restore from backup if move failed
        cp "$backup_file" "$wt_settings" 2>/dev/null
        rm -f "$temp_file"
        return 1
      fi
    else
      rm -f "$temp_file"
      return 1
    fi
  else
    rm -f "$temp_file"
    return 1
  fi
}

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

  # Detect Windows username
  local win_user
  if ! win_user=$(_detect_windows_username); then
    printf "  %b✗%b Windows Terminal: Could not detect Windows username\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    return 1
  fi

  # Find Windows Terminal settings path
  local wt_settings
  if ! wt_settings=$(_find_wt_settings_path "$win_user"); then
    printf "  %b✗%b Windows Terminal: settings.json not found for user %s\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" "$win_user" >&2
    return 1
  fi

  # Check if file is writable
  if [[ ! -w "$wt_settings" ]]; then
    printf "  %b✗%b Windows Terminal: settings.json not writable\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    return 1
  fi

  # Find theme files directory
  local theme_dir
  if ! theme_dir=$(_find_wt_theme_directory); then
    printf "  %b✗%b Windows Terminal: Theme files not found\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    printf "    Expected: %s/devbase/files/windows-terminal/\n" "${XDG_DATA_HOME}" >&2
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

  # Build themes JSON array
  local themes_array theme_count
  # Capture stderr (count) and stdout (JSON) separately
  theme_count=$(_build_themes_json_array "$theme_dir" 2>&1 >/dev/null)
  themes_array=$(_build_themes_json_array "$theme_dir" 2>/dev/null)

  # Check if we found any theme files
  if [[ $theme_count -eq 0 ]]; then
    printf "  %b✗%b Windows Terminal: No theme files found in %s\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" "$theme_dir" >&2
    return 1
  fi

  # Validate themes array is valid JSON
  if ! echo "$themes_array" | jq empty 2>/dev/null; then
    printf "  %b✗%b Windows Terminal: Invalid theme JSON files\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    return 1
  fi

  # Inject themes into settings.json
  if _inject_themes_to_settings "$wt_settings" "$themes_array" "$backup_file"; then
    printf "  %b✓%b Windows Terminal: All 12 DevBase themes installed\n" "${DEVBASE_COLORS[GREEN]}" "${DEVBASE_COLORS[NC]}" >&2
    echo "Themes installed successfully" >&2
    return 0
  else
    printf "  %b✗%b Windows Terminal: Failed to update settings.json\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_COLORS[NC]}" >&2
    echo "Failed to inject themes" >&2
    return 1
  fi
}
