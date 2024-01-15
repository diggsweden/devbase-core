#!/usr/bin/env bash
set -uo pipefail

# Brief: Generate a random 7-character SSH passphrase
# Params: None
# Returns: Echoes passphrase to stdout
# Side-effects: None
generate_ssh_passphrase() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 6 | head -c 7
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 7
  fi
}

# Verify devbase environment is set
if [[ -z "${DEVBASE_ROOT:-}" ]]; then
  echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# Common utilities for devbase installation scripts
# Guard against multiple sourcing
[[ -n "${_DEVBASE_UTILS_SOURCED:-}" ]] && return 0
_DEVBASE_UTILS_SOURCED=1

# Internal configuration constants (not exported)
readonly _SLEEP_DURATION=2
readonly _TIMEOUT_QUICK=10
readonly _TIMEOUT_STANDARD=30
readonly _TIMEOUT_TRANSFER=60
readonly _RETRY_ATTEMPTS=3
readonly _RETRY_DELAY=5
readonly _FIND_DEPTH=5

# System limits (only used locally)
readonly _ULIMIT_NOFILE=65536 # Max open files
readonly _ULIMIT_NPROC=32768  # Max processes

# Time constants (internal use only)
readonly _SECONDS_PER_DAY=86400
readonly _CERT_EXPIRY_WARNING_DAYS=30

# Error handling patterns:
#   die "message"     - Fatal errors that stop execution
#   return 1         - Function failures for caller to handle
# Avoid: blind 2>/dev/null, || true without reason

declare -gA COMMAND_CACHE

# Brief: Check if command exists with caching
# Params: $1 - command name
# Uses: COMMAND_CACHE (global associative array)
# Returns: 0 if exists, 1 if not
# Side-effects: Updates COMMAND_CACHE
command_exists() {
  local cmd="$1"
  validate_not_empty "$cmd" "command name" || return 1

  [[ -n "${COMMAND_CACHE[$cmd]:-}" ]] && return "${COMMAND_CACHE[$cmd]}"

  if command -v "$cmd" &>/dev/null; then
    COMMAND_CACHE[$cmd]=0
    return 0
  else
    COMMAND_CACHE[$cmd]=1
    return 1
  fi
}

# Brief: Display fatal error message and exit
# Params: $@ - error message
# Uses: DEVBASE_COLORS, DEVBASE_SYMBOLS (globals)
# Returns: Never returns (exits with 1)
# Side-effects: Exits process
die() {
  printf "\n"
  printf "  %b%s%b %b\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_SYMBOLS[CROSS]}" "${DEVBASE_COLORS[NC]}" "$*" >&2
  printf "\n"
  exit 1
}

# Levels: step (main action), info (details), success (completion), warning, error (fatal)

# Brief: Validate path for security (traversal, system dirs, whitelisting)
# Params: $1 - path to validate, $2 - strict_mode (true/false, default: true)
# Returns: 0 if valid, calls die() on invalid paths
# Side-effects: None (validation only)
validate_path() {
  local path="$1"
  local strict_mode="${2:-true}"

  validate_not_empty "$path" "path" || die "Path required"

  local original_user="${SUDO_USER:-$USER}"
  local user_home
  user_home=$(getent passwd "$original_user" | cut -d: -f6)

  [[ -n "$user_home" ]] || die "Cannot determine user home directory"

  # Resolve real path (handles symlinks)
  local real_path
  real_path=$(realpath -m "$path" 2>/dev/null) || die "Cannot resolve path: $path"

  # SECURITY CHECKS (always applied)
  [[ "$real_path" = /* ]] || die "Path must be absolute: $real_path"

  [[ "$real_path" != *".."* ]] || die "Path traversal detected: $real_path"

  # STRICT MODE WHITELIST
  if [[ "$strict_mode" == "true" ]]; then
    case "$real_path" in
    / | /bin | /boot | /dev | /etc | /lib | /lib64 | /proc | /root | /sbin | /sys | /usr | /var)
      die "Cannot operate on system directory: $real_path"
      ;;
    /mnt | /mnt/* | /media | /media/*)
      die "Cannot operate on mount point: $real_path"
      ;;
    /home)
      die "Cannot operate on /home root"
      ;;
    esac

    case "$real_path" in
    /tmp/* | /var/tmp/*)
      [[ "$real_path" != "/tmp" ]] && [[ "$real_path" != "/var/tmp" ]] || die "Cannot operate on temp directory root"
      ;;
    "${user_home}") ;;
    "${user_home}"/.devbase_backup* | "${user_home}"/.config/* | "${user_home}"/.local/* | "${user_home}"/.cache/*) ;;
    "${user_home}"/development/* | "${user_home}"/devbase-*) ;;
    /opt/devbase/*) ;;
    *)
      die "Path outside allowed zones: $real_path (must be in user home subdirs, /tmp/*, or /opt/devbase/*)"
      ;;
    esac

    [[ ${#real_path} -ge 4 ]] || die "Path too short: $real_path"
  fi

  return 0
}

# Brief: Extract UPPERCASE variable names from template content (pure logic)
# Params: $1 - template_content (multi-line string)
# Returns: Space-separated list of $VAR names to stdout (e.g., "$FOO $BAR")
# Side-effects: None (pure function)
_extract_uppercase_vars() {
  local content="$1"
  echo "$content" | grep -o '\${\?[A-Z_][A-Z0-9_]*}\?' |
    sed 's/[{}$]//g' | sort -u | sed 's/^/$/g' | tr '\n' ' '
}

# Brief: Process template with envsubst, only substituting UPPERCASE variables
# Params: $1 - template_file, $2 - output_file
# Uses: _extract_uppercase_vars (internal logic function)
# Returns: 0 on success, 1 on error
# Side-effects: Creates/overwrites output_file
envsubst_preserve_undefined() {
  local template_file="$1"
  local output_file="$2"

  validate_not_empty "$template_file" "template file" || return 1
  validate_not_empty "$output_file" "output file" || return 1
  validate_file_exists "$template_file" "Template file" || return 1

  # Extract variables using pure logic function
  local vars_to_sub
  vars_to_sub=$(_extract_uppercase_vars "$(cat "$template_file")")

  if [[ -n "$vars_to_sub" ]]; then
    # Substitute only the UPPERCASE variables found
    envsubst "$vars_to_sub" <"$template_file" >"$output_file"
  else
    # No variables to substitute, just copy
    cp "$template_file" "$output_file"
  fi

  return $?
}

# Brief: Retry command with exponential backoff and jitter
# Params: [--attempts N] [--delay N] -- command args...
# Uses: _RETRY_ATTEMPTS, _RETRY_DELAY (constants)
# Returns: 0 on success, last exit code on failure
# Side-effects: Executes command, sleeps between retries
retry_command() {
  local max_attempts="${_RETRY_ATTEMPTS}"
  local base_delay="${_RETRY_DELAY}"

  while [[ $# -gt 0 ]] && [[ "$1" != "--" ]]; do
    case "$1" in
    --attempts)
      max_attempts="$2"
      shift 2
      ;;
    --delay)
      base_delay="$2"
      shift 2
      ;;
    *)
      break # Not an option, must be the command
      ;;
    esac
  done

  [[ "$1" == "--" ]] && shift

  local attempt=1
  local exit_code=0
  local current_delay="$base_delay"
  local command=("$@")

  while [[ $attempt -le $max_attempts ]]; do
    if "${command[@]}"; then
      return 0
    fi

    exit_code=$?

    if [[ $attempt -eq $max_attempts ]]; then
      show_progress warning "Command failed after $max_attempts attempts"
      return $exit_code
    fi

    # Calculate exponential backoff with jitter (2, 4, 8 seconds + random 0-2)
    current_delay=$((base_delay * (2 ** (attempt - 1)) + RANDOM % 3))

    printf "    %s Attempt %d/%d failed, retrying in %ds...\n" \
      "${DEVBASE_COLORS[YELLOW]}⚠${DEVBASE_COLORS[NC]}" "$attempt" "$max_attempts" "$current_delay"

    sleep "$current_delay"
    attempt=$((attempt + 1))
  done

  return $exit_code
}

# Brief: Calculate relative path and validate for security (pure logic)
# Params: $1 - file_path, $2 - src_dir
# Returns: Echoes relative path to stdout, or empty string if invalid
# Side-effects: None (pure function)
_calculate_safe_relative_path() {
  local file="$1"
  local src_dir="$2"
  local rel_path="${file#"$src_dir"/}"

  # Path traversal protection
  [[ "$rel_path" == *..* ]] && return 1
  [[ "$rel_path" == /* ]] && return 1

  echo "$rel_path"
  return 0
}

# Brief: Determine backup path for a file (pure logic)
# Params: $1 - rel_path, $2 - backup_base_dir
# Returns: Echoes full backup path to stdout
# Side-effects: None (pure function)
_get_backup_path() {
  local rel_path="$1"
  local backup_base="$2"
  echo "$backup_base/$rel_path"
}

# Brief: Merge source dotfiles into target with backup of existing files
# Params: $1 - src_dir, $2 - target_dir (default: $HOME)
# Uses: DEVBASE_BACKUP_DIR, _FIND_DEPTH, _calculate_safe_relative_path, _get_backup_path (globals/functions)
# Returns: 0 on success, 1 on error
# Side-effects: Creates backups, copies files
merge_dotfiles_with_backup() {
  local src_dir="$1"
  local target_dir="${2:-$HOME}"

  validate_not_empty "$src_dir" "source directory" || return 1
  validate_dir_exists "$src_dir" "Source directory" || return 1
  validate_path "$src_dir" "true" || return 1
  validate_path "$target_dir" "true" || return 1

  local dotfiles_backup="${DEVBASE_BACKUP_DIR}/dot_backup"
  mkdir -p "$dotfiles_backup"

  while IFS= read -r -d '' file; do
    # Use pure logic function to calculate safe path
    local rel_path
    rel_path=$(_calculate_safe_relative_path "$file" "$src_dir") || continue

    local target_file="$target_dir/$rel_path"
    [[ -e "$target_file" ]] && {
      # Use pure logic function to determine backup path
      local backup_path
      backup_path=$(_get_backup_path "$rel_path" "$dotfiles_backup")
      mkdir -p "$(dirname "$backup_path")"
      # Symlink protection
      cp --no-dereference -r "$target_file" "$backup_path"
    }
  done < <(find "$src_dir" -maxdepth "$_FIND_DEPTH" -type f -print0)

  # Now copy new dotfiles (NOTE: still uses cp -r which follows symlinks in src)
  cp -r "$src_dir"/. "$target_dir/"
  return 0
}

# Brief: Create all required user directories (XDG, dev tools, etc.)
# Params: None
# Uses: XDG_*, DEVBASE_*, HOME (globals)
# Returns: 0 always
# Side-effects: Creates directories, sets permissions
ensure_user_dirs() {
  show_progress info "Setting up user directories..."

  local dirs=(
    # XDG base directories
    "$XDG_CONFIG_HOME"
    "$XDG_CONFIG_HOME/systemd/user"
    "$XDG_BIN_HOME"
    "$XDG_DATA_HOME"
    "$XDG_DATA_HOME/ca-certificates"
    "$XDG_DATA_HOME/devbase/libs"
    "${DEVBASE_BACKUP_DIR}"
    "$XDG_CACHE_HOME"
    "${DEVBASE_CACHE_DIR}"
    "${DEVBASE_CACHE_DIR}/downloads"
    "${DEVBASE_CACHE_DIR}/mise"
    "${DEVBASE_CACHE_DIR}/vscode-extensions"

    # Shell configurations
    "$XDG_CONFIG_HOME/fish"
    "$XDG_CONFIG_HOME/fish/completions"
    "$XDG_CONFIG_HOME/fish/conf.d"
    "$XDG_CONFIG_HOME/mise"
    "$XDG_CONFIG_HOME/git"
    "$XDG_CONFIG_HOME/nvim/lua/plugins"
    "${DEVBASE_CONFIG_DIR}"

    # SSH
    "$HOME/.ssh"
    "$XDG_CONFIG_HOME/ssh" # XDG-compliant SSH config directory

    # Development tools
    "$HOME/.m2"         # Maven
    "$HOME/.gradle"     # Gradle
    "$HOME/development" # Git repos
    "$HOME/development/gitlab.com"
    "$HOME/development/github.com"
    "$HOME/development/bitbucket.org"
    "$HOME/development/codeberg.org"
    "$HOME/development/code.europa.eu"
    "$HOME/development/devcerts" # Development certificates
    "$HOME/notes" # Notes directory
  )

  local created_count=0
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir"
      created_count=$((created_count + 1))
    fi
  done

  [[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh"
  [[ -d "$XDG_CONFIG_HOME/ssh" ]] && chmod 755 "$XDG_CONFIG_HOME/ssh"
  [[ -d "${DEVBASE_CACHE_DIR}" ]] && chmod 700 "${DEVBASE_CACHE_DIR}"

  local total_dirs=${#dirs[@]}
  local existing=$((total_dirs - created_count))

  local msg="User directories ready ($total_dirs total"
  [[ $created_count -gt 0 ]] && msg="${msg}, $created_count created"
  [[ $existing -gt 0 ]] && msg="${msg}, $existing existing"
  msg="${msg})"

  show_progress success "$msg"
  return 0
}

# Brief: Backup existing file/directory by appending timestamped suffix
# Params: $1 - target_path, $2 - backup_suffix
# Returns: 0 always
# Side-effects: Renames target if it exists
backup_if_exists() {
  local target_path="$1"
  local backup_suffix="$2"

  validate_not_empty "$target_path" "target path" || return 1
  validate_not_empty "$backup_suffix" "backup suffix" || return 1

  if [[ -e "$target_path" ]]; then
    local backup_path="${target_path}-${backup_suffix}"
    local counter=1
    while [[ -e "$backup_path" ]]; do
      backup_path="${target_path}-${backup_suffix}-${counter}"
      counter=$((counter + 1))
    done
    mv "$target_path" "$backup_path"
  fi
  return 0
}

# Brief: Run mise command from HOME directory
# Params: $@ - mise arguments
# Uses: HOME (global)
# Returns: mise exit code
# Side-effects: Runs mise in subshell from HOME
run_mise_from_home_dir() {
  (cd "$HOME" && mise "$@")
}
