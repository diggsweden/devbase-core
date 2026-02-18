#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Verify devbase environment is set
if [[ -z "${DEVBASE_ROOT:-}" ]]; then
	echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
	return 1
fi

# Common utilities for devbase installation scripts
# Guard against multiple sourcing
[[ -n "${_DEVBASE_UTILS_SOURCED:-}" ]] && return 0
_DEVBASE_UTILS_SOURCED=1

# Brief: Generate a random 12-character SSH passphrase (NIST minimum)
# Params: None
# Returns: Echoes passphrase to stdout
# Side-effects: None
generate_ssh_passphrase() {
	local pass
	if command -v openssl >/dev/null 2>&1; then
		pass=$(openssl rand -base64 12 2>/dev/null)
	else
		pass=$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 16)
	fi
	# Use bash string slicing to avoid SIGPIPE from head closing early
	printf '%s' "${pass:0:12}"
}

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
# Side-effects: Updates COMMAND_CACHE (only caches positive results)
# Note: Negative results are not cached since commands may be installed mid-session
command_exists() {
	local cmd="$1"
	validate_not_empty "$cmd" "command name" || return 1

	[[ "${COMMAND_CACHE[$cmd]:-}" == "0" ]] && return 0

	if command -v "$cmd" &>/dev/null; then
		COMMAND_CACHE[$cmd]=0
		return 0
	else
		return 1
	fi
}

# Brief: Display fatal error message and exit
# Params: $@ - error message
# Uses: DEVBASE_COLORS, DEVBASE_SYMBOLS, DEVBASE_TUI_MODE (globals)
# Returns: Never returns (exits with 1)
# Side-effects: Exits process
die() {
	# In whiptail mode, show error in a dialog
	if [[ "${DEVBASE_TUI_MODE:-}" == "whiptail" ]] && command -v whiptail &>/dev/null; then
		whiptail --backtitle "$WT_BACKTITLE" --title "Fatal Error" \
			--msgbox "$*" 10 60 2>/dev/null || true
	else
		printf "\n"
		printf "  %b%s%b %b\n" "${DEVBASE_COLORS[RED]}" "${DEVBASE_SYMBOLS[CROSS]}" "${DEVBASE_COLORS[NC]}" "$*" >&2
		printf "\n"
	fi
	exit 1
}

# Levels: step (main action), info (details), success (completion), warning, error (fatal)

# Brief: Refresh sudo credentials to prevent timeout during long operations
# Params: None
# Returns: 0 on success, 1 on failure
# Side-effects: Extends sudo timeout
sudo_refresh() {
	sudo -v
}

# Brief: Determine writable temp root directory
# Params: None
# Returns: Path to temp directory
get_temp_root() {
	local candidate
	for candidate in "${TMPDIR:-}" "${XDG_RUNTIME_DIR:-}" "/tmp"; do
		[[ -n "$candidate" ]] || continue
		if [[ -d "$candidate" ]] && [[ -w "$candidate" ]]; then
			printf "%s" "$candidate"
			return 0
		fi
	done

	printf "%s" "/tmp"
}

# Brief: Create temp directory with prefix
# Params: $1 - prefix (optional, default: devbase)
# Returns: Created temp directory path
make_temp_dir() {
	local prefix="${1:-devbase}"
	local temp_root
	temp_root=$(get_temp_root)
	mktemp -d "${temp_root%/}/${prefix}.XXXXXX"
}

# Brief: Validate path for security (traversal, system dirs, whitelisting)
# Params: $1 - path to validate, $2 - strict_mode (true/false, default: true)
# Returns: 0 if valid, calls die() on invalid paths
# Side-effects: None (validation only)
validate_path() {
	local path="$1"
	local strict_mode="${2:-true}"

	validate_not_empty "$path" "path" || die "Path required"

	# Determine user home directory
	local original_user="${SUDO_USER:-$USER}"
	local user_home
	user_home=$(getent passwd "$original_user" | cut -d: -f6)
	[[ -n "$user_home" ]] || die "Cannot determine user home directory"

	# Resolve real path (handles symlinks)
	local real_path
	real_path=$(realpath -m "$path" 2>/dev/null) || die "Cannot resolve path: $path"

	# ===== SECURITY CHECKS (always applied) =====
	[[ "$real_path" = /* ]] || die "Path must be absolute: $real_path"

	# ===== STRICT MODE WHITELIST =====
	if [[ "$strict_mode" == "true" ]]; then
		# Block system directories
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

		# Allow only user-writable locations
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
	# shellcheck disable=SC2016 # Single quotes intentional - we're searching for literal $ patterns
	echo "$content" |
		grep -o '\${\?[A-Z_][A-Z0-9_]*}\?' | # Extract ${VAR} or $VAR patterns
		sed 's/[{}$]//g' |                   # Remove $ { } characters
		sort -u |                            # Get unique variable names only
		sed 's/^/$/g' |                      # Add $ prefix back for envsubst
		tr '\n' ' '                          # Convert to space-separated list
}

# Brief: Process template with envsubst, only substituting UPPERCASE variables
# Params: $1 - template_file, $2 - output_file
# Uses: _extract_uppercase_vars, validate_template_variables (functions)
# Returns: 0 on success, 1 on error
# Side-effects: Creates/overwrites output_file, validates variables before processing
envsubst_preserve_undefined() {
	local template_file="$1"
	local output_file="$2"

	validate_not_empty "$template_file" "template file" || return 1
	validate_not_empty "$output_file" "output file" || return 1
	validate_file_exists "$template_file" "Template file" || return 1

	# Extract variables using pure logic function
	local vars_to_sub
	vars_to_sub=$(_extract_uppercase_vars "$(<"$template_file")")

	# Validate that required template variables are set before processing
	if [[ -n "$vars_to_sub" ]]; then
		validate_template_variables "$template_file" "$vars_to_sub" || return 1
	fi

	# Filter out runtime variables (should not be replaced by envsubst)
	# These variables are meant to be evaluated at runtime by the shell
	local runtime_vars=("XDG_RUNTIME_DIR" "USER_UID")
	local filtered_vars=""
	for var in $vars_to_sub; do
		local var_name="${var#\$}"
		local is_runtime=false
		for runtime_var in "${runtime_vars[@]}"; do
			if [[ "$var_name" == "$runtime_var" ]]; then
				is_runtime=true
				break
			fi
		done
		if [[ "$is_runtime" == false ]]; then
			filtered_vars="$filtered_vars $var"
		fi
	done

	# Proceed with substitution (using filtered list)
	if [[ -n "$filtered_vars" ]]; then
		# Substitute only the UPPERCASE variables found (excluding runtime vars)
		envsubst "$filtered_vars" <"$template_file" >"$output_file"
	else
		# No variables to substitute, just copy
		cp "$template_file" "$output_file"
	fi
}

# Brief: Retry command with exponential backoff and jitter
# Params: [--attempts N] [--delay N] -- command args...
# Uses: _RETRY_ATTEMPTS, _RETRY_DELAY (constants)
# Returns: 0 on success, last exit code on failure
# Side-effects: Executes command, sleeps between retries
declare -ag DEVBASE_GLOBAL_WARNINGS=()

add_global_warning() {
	local message="$1"
	DEVBASE_GLOBAL_WARNINGS+=("$message")
	show_progress warning "$message"
}

show_global_warnings() {
	if [[ ${#DEVBASE_GLOBAL_WARNINGS[@]} -eq 0 ]]; then
		return 0
	fi

	show_progress warning "Warnings during setup:"
	for warning in "${DEVBASE_GLOBAL_WARNINGS[@]}"; do
		show_progress warning "  - $warning"
	done

	DEVBASE_GLOBAL_WARNINGS=()
	return 0
}

retry_command() {
	local max_attempts="${_RETRY_ATTEMPTS}"
	local base_delay="${_RETRY_DELAY}"

	# ===== Parse optional arguments =====
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

	# ===== Retry loop with exponential backoff =====
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

		show_progress warning "Attempt $attempt/$max_attempts failed, retrying in ${current_delay}s..."

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
	cp -r "$src_dir"/. "$target_dir/" || {
		show_progress error "Failed to copy dotfiles from $src_dir to $target_dir"
		return 1
	}
	return 0
}

# Brief: Create all required user directories (XDG, dev tools, etc.)
# Params: None
# Uses: XDG_*, DEVBASE_*, HOME (globals)
# Returns: 0 always
# Side-effects: Creates directories, sets permissions
ensure_user_dirs() {
	show_progress info "Setting up user directories..."

	# ===== XDG base directories =====
	local xdg_dirs=(
		"$XDG_CONFIG_HOME"
		"$XDG_CONFIG_HOME/systemd/user"
		"$XDG_BIN_HOME"
		"$XDG_DATA_HOME"
		"$XDG_DATA_HOME/ca-certificates"
		"$XDG_DATA_HOME/devbase/libs"
		"$XDG_DATA_HOME/devbase/core"
		"$XDG_DATA_HOME/devbase/custom"
		"$XDG_CACHE_HOME"
	)

	# ===== DevBase directories =====
	local devbase_dirs=(
		"${DEVBASE_BACKUP_DIR}"
		"${DEVBASE_CONFIG_DIR}"
		"${DEVBASE_CACHE_DIR}"
		"${DEVBASE_CACHE_DIR}/downloads"
		"${DEVBASE_CACHE_DIR}/mise"
		"${DEVBASE_CACHE_DIR}/vscode-extensions"
	)

	# ===== Shell and editor configurations =====
	local config_dirs=(
		"$XDG_CONFIG_HOME/fish"
		"$XDG_CONFIG_HOME/fish/completions"
		"$XDG_CONFIG_HOME/fish/conf.d"
		"$XDG_CONFIG_HOME/mise"
		"$XDG_CONFIG_HOME/git"
		"$XDG_CONFIG_HOME/nvim/lua/plugins"
	)

	# ===== SSH directories =====
	local ssh_dirs=(
		"$HOME/.ssh"
		"$XDG_CONFIG_HOME/ssh"
	)

	# ===== Development tool caches =====
	local tool_dirs=(
		"$HOME/.m2"
		"$HOME/.gradle"
	)

	# ===== Development project directories =====
	local project_dirs=(
		"$HOME/development"
		"$HOME/development/gitlab.com"
		"$HOME/development/github.com"
		"$HOME/development/bitbucket.org"
		"$HOME/development/codeberg.org"
		"$HOME/development/code.europa.eu"
		"$HOME/development/devcerts"
		"$HOME/notes"
	)

	# Combine all directories
	local dirs=(
		"${xdg_dirs[@]}"
		"${devbase_dirs[@]}"
		"${config_dirs[@]}"
		"${ssh_dirs[@]}"
		"${tool_dirs[@]}"
		"${project_dirs[@]}"
	)

	# ===== Create directories =====
	local created_count=0
	for dir in "${dirs[@]}"; do
		if [[ ! -d "$dir" ]]; then
			mkdir -p "$dir"
			created_count=$((created_count + 1))
		fi
	done

	# ===== Set permissions on security-sensitive directories =====
	[[ -d "$HOME/.ssh" ]] && chmod 700 "$HOME/.ssh"
	[[ -d "$XDG_CONFIG_HOME/ssh" ]] && chmod 755 "$XDG_CONFIG_HOME/ssh"
	[[ -d "${DEVBASE_CACHE_DIR}" ]] && chmod 700 "${DEVBASE_CACHE_DIR}"

	# ===== Report results =====
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

# Brief: Download file with optional caching support
# Params: $1 - url, $2 - target_file, $3 - cache_filename, $4 - package_name (for messages)
#         $5 - checksum_url (optional), $6 - expected_checksum (optional), $7 - timeout (default 30)
# Uses: DEVBASE_DEB_CACHE (optional global), validate_optional_dir, download_file (functions)
# Returns: 0 on success, 1 on failure
# Side-effects: Downloads file, may cache it if DEVBASE_DEB_CACHE is set
download_with_cache() {
	local url="$1"
	local target="$2"
	local cache_filename="$3"
	local package_name="${4:-package}"
	local checksum_url="${5:-}"
	local expected_checksum="${6:-}"
	local timeout="${7:-30}"

	validate_not_empty "$url" "Download URL" || return 1
	validate_not_empty "$target" "Target file" || return 1
	validate_not_empty "$cache_filename" "Cache filename" || return 1

	local has_checksum=1
	[[ -n "$checksum_url" || -n "$expected_checksum" ]] && has_checksum=0

	local strict_mode
	strict_mode=$(_normalize_strict_mode "${DEVBASE_STRICT_CHECKSUMS:-fail}")

	local allowlisted=false
	_checksum_allowlisted "$url" && allowlisted=true

	if [[ "$has_checksum" -ne 0 ]]; then
		if [[ "$allowlisted" == "true" ]]; then
			add_global_warning "Checksum allowlisted for download: $url"
		else
			case "$strict_mode" in
			fail)
				show_progress error "Checksum required for download: $url"
				return 1
				;;
			warn)
				add_global_warning "No checksum available for download: $url"
				;;
			esac
		fi
	fi

	if validate_optional_dir "DEVBASE_DEB_CACHE" "Package cache"; then
		local cached_file="${DEVBASE_DEB_CACHE}/${cache_filename}"

		if [[ -f "$cached_file" ]]; then
			local cached_ok=false
			if [[ "$has_checksum" -eq 0 ]]; then
				local rc=0
				show_progress info "Verifying cached ${package_name}"
				if [[ -n "$expected_checksum" ]]; then
					verify_checksum_value "$cached_file" "$expected_checksum" || rc=1
				else
					verify_checksum_from_url "$cached_file" "$checksum_url" "$timeout" || rc=$?
				fi

				if [[ $rc -eq 0 ]]; then
					cached_ok=true
				elif [[ $rc -eq 2 ]]; then
					if [[ "$strict_mode" == "fail" ]]; then
						show_progress error "Checksum required but unavailable for cached ${package_name}"
						return 1
					fi
					show_progress warning "Could not verify cached ${package_name}; re-downloading"
				else
					show_progress warning "Cached ${package_name} checksum mismatch - re-downloading"
					rm -f "$cached_file"
				fi
			else
				cached_ok=true
			fi

			if [[ "$cached_ok" == "true" ]]; then
				show_progress info "Using cached ${package_name}"
				cp "$cached_file" "$target" && return 0
				show_progress warning "Failed to copy from cache, will download"
			fi
		fi

		if download_file "$url" "$target" "$checksum_url" "$expected_checksum" "" "$timeout"; then
			mkdir -p "${DEVBASE_DEB_CACHE}"
			cp "$target" "$cached_file" 2>/dev/null || true
			return 0
		fi
		return 1
	fi

	download_file "$url" "$target" "$checksum_url" "$expected_checksum" "" "$timeout"
}

# Brief: Safely remove temporary directory with path validation
# Params: None
# Uses: _DEVBASE_TEMP (global)
# Returns: 0 always
# Side-effects: Removes _DEVBASE_TEMP directory if path matches expected pattern
cleanup_temp_directory() {
	if [[ -z "${_DEVBASE_TEMP:-}" ]]; then
		return 0
	fi

	if [[ ! -d "${_DEVBASE_TEMP}" ]]; then
		return 0
	fi

	local real_path
	real_path=$(realpath -m "${_DEVBASE_TEMP}" 2>/dev/null) || return 0

	local temp_root
	temp_root=$(get_temp_root)
	temp_root=$(realpath -m "$temp_root" 2>/dev/null || printf "%s" "/tmp")

	case "$real_path" in
	"${temp_root%/}/devbase."*)
		rm -rf "$real_path" 2>/dev/null || true
		;;
	esac

	return 0
}

# Brief: Enable and start systemd service with indented output
# Params: $1 - service_name, $2 - description (for success message)
# Returns: 0 on success, 1 on failure
# Side-effects: Enables and starts systemd service
systemctl_enable_start() {
	local service="$1"
	local description="${2:-$service}"

	validate_not_empty "$service" "Service name" || return 1

	# Capture output to filter it
	local output
	output=$(sudo systemctl enable "$service" 2>&1)
	local result=$?

	if [[ $result -eq 0 ]]; then
		# Success - only show verbose output in debug mode
		if [[ "$DEVBASE_DEBUG" == "1" ]]; then
			printf "    %s\n" "$output"
		fi
		sudo systemctl start "$service" >/dev/null 2>&1 || true
		show_progress success "${description} enabled and started"
		return 0
	else
		# Failure - always show error output
		printf "    %s\n" "$output" >&2
		show_progress warning "Failed to enable ${description}"
		return 1
	fi
}

# Brief: Disable and stop systemd service with indented output
# Params: $1 - service_name, $2 - description (for success message)
# Returns: 0 always
# Side-effects: Disables and stops systemd service
systemctl_disable_stop() {
	local service="$1"
	local description="${2:-$service}"

	validate_not_empty "$service" "Service name" || return 1

	if sudo systemctl stop "$service" >/dev/null 2>&1; then
		# Capture output to filter it
		local output
		output=$(sudo systemctl disable "$service" 2>&1)
		local result=$?

		if [[ $result -eq 0 ]]; then
			# Success - only show verbose output in debug mode
			if [[ "$DEVBASE_DEBUG" == "1" ]]; then
				printf "    %s\n" "$output"
			fi
		else
			# Failure - always show error output
			printf "    %s\n" "$output" >&2
		fi
		show_progress success "${description} disabled"
	fi
	return 0
}
