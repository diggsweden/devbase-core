#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Common functions shared between gum and whiptail TUI implementations
# This file should be sourced by collect-user-preferences-gum.sh and
# collect-user-preferences-whiptail.sh

if [[ -z "${DEVBASE_ROOT:-}" ]]; then
	echo "ERROR: DEVBASE_ROOT not set. This script must be sourced from setup.sh" >&2
	return 1
fi

source "${DEVBASE_ROOT}/libs/defaults.sh"

# =============================================================================
# NON-INTERACTIVE MODE
# =============================================================================

setup_non_interactive_mode() {
	validate_var_set "DEVBASE_CONFIG_DIR" || return 1
	validate_var_set "USER" || return 1

	printf "\n%bRunning in non-interactive mode with defaults...%b\n" \
		"${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"

	# Determine passphrase: use the user-supplied value or generate one.
	# Track whether we generated it so we know to write it to disk later —
	# an explicit boolean flag makes this intent clear and is robust against
	# any future code that might modify SSH_KEY_PASSPHRASE between these two
	# decisions (the previous double-check of the same variable was fragile).
	local passphrase_was_generated=false
	if [[ -z "${SSH_KEY_PASSPHRASE:-}" ]]; then
		DEVBASE_SSH_PASSPHRASE="$(generate_ssh_passphrase)"
		passphrase_was_generated=true
	else
		DEVBASE_SSH_PASSPHRASE="$SSH_KEY_PASSPHRASE"
	fi
	export DEVBASE_SSH_PASSPHRASE

	if [[ "$passphrase_was_generated" == true ]]; then
		export GENERATED_SSH_PASSPHRASE="true"
		mkdir -p "${DEVBASE_CONFIG_DIR}"
		local _tmp_passphrase="${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
		printf '%s\n' "$DEVBASE_SSH_PASSPHRASE" >"$_tmp_passphrase"
		chmod 600 "$_tmp_passphrase"
		# Guard against interrupted installs leaving the passphrase on disk.
		# show_completion_message (install.sh) reads and deletes this on success;
		# this EXIT trap ensures cleanup on any other exit (INT, TERM, crash).
		# Path is expanded at registration time — safe after this function returns.
		# shellcheck disable=SC2064 # Intentional: expand now, not at trap-fire time
		trap "rm -f -- '${_tmp_passphrase}'" EXIT
	fi

	validate_var_set "GIT_NAME" || return 1
	validate_var_set "GIT_EMAIL" || return 1
	# shellcheck disable=SC2153
	export DEVBASE_GIT_AUTHOR="${GIT_NAME}"
	# shellcheck disable=SC2153
	export DEVBASE_GIT_EMAIL="${GIT_EMAIL}"

	[[ -z "$DEVBASE_SSH_KEY_ACTION" ]] && DEVBASE_SSH_KEY_ACTION="new"
	apply_preference_defaults

	export DEVBASE_THEME DEVBASE_FONT DEVBASE_VSCODE_INSTALL DEVBASE_VSCODE_EXTENSIONS
	export DEVBASE_INSTALL_DEVTOOLS DEVBASE_INSTALL_LAZYVIM DEVBASE_INSTALL_INTELLIJ DEVBASE_INSTALL_JMC
	export DEVBASE_ZELLIJ_AUTOSTART DEVBASE_ENABLE_GIT_HOOKS DEVBASE_SELECTED_PACKS DEVBASE_SSH_KEY_ACTION

	printf "  Git Name: %s\n  Git Email: %s\n  Theme: %s\n  Packs: %s\n" \
		"$DEVBASE_GIT_AUTHOR" "$DEVBASE_GIT_EMAIL" "$DEVBASE_THEME" "$DEVBASE_SELECTED_PACKS"
	[[ "${GENERATED_SSH_PASSPHRASE:-}" == "true" ]] && printf "  SSH Key: Generated with secure passphrase\n"
}

# =============================================================================
# LOAD SAVED PREFERENCES
# =============================================================================

load_saved_preferences() {
	local prefs_file="${DEVBASE_CONFIG_DIR}/preferences.yaml"
	[[ ! -f "$prefs_file" ]] && return 1
	command -v yq &>/dev/null || {
		show_progress warning "yq not found"
		return 1
	}

	# Only show message in gum mode (whiptail handles its own display)
	if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]]; then
		printf "\n%bLoading saved preferences...%b\n" "${DEVBASE_COLORS[BOLD_BLUE]}" "${DEVBASE_COLORS[NC]}"
	fi

	_yq_read() {
		local val
		val=$(yq "$1" "$2")
		[[ "$val" == "null" ]] && echo "" || echo "$val"
	}

	DEVBASE_THEME=$(_yq_read '.theme' "$prefs_file")
	DEVBASE_FONT=$(_yq_read '.font' "$prefs_file")
	DEVBASE_GIT_AUTHOR=$(_yq_read '.git.author' "$prefs_file")
	DEVBASE_GIT_EMAIL=$(_yq_read '.git.email' "$prefs_file")
	DEVBASE_SSH_KEY_NAME=$(_yq_read '.ssh.key_name' "$prefs_file")
	EDITOR=$(_yq_read '.editor.default' "$prefs_file")
	VISUAL="$EDITOR"

	DEVBASE_VSCODE_INSTALL=$(_yq_read '.vscode.install' "$prefs_file")
	DEVBASE_VSCODE_EXTENSIONS=$(_yq_read '.vscode.extensions' "$prefs_file")
	DEVBASE_INSTALL_LAZYVIM=$(_yq_read '.ide.lazyvim' "$prefs_file")
	DEVBASE_INSTALL_INTELLIJ=$(_yq_read '.ide.intellij' "$prefs_file")
	DEVBASE_INSTALL_JMC=$(_yq_read '.ide.jmc' "$prefs_file")
	DEVBASE_ZELLIJ_AUTOSTART=$(_yq_read '.tools.zellij_autostart' "$prefs_file")
	DEVBASE_ENABLE_GIT_HOOKS=$(_yq_read '.tools.git_hooks' "$prefs_file")
	DEVBASE_SELECTED_PACKS=$(yq -r '.packs // [] | .[]' "$prefs_file" | tr '\n' ' ' | sed 's/ $//')

	apply_preference_defaults

	export DEVBASE_THEME DEVBASE_FONT DEVBASE_GIT_AUTHOR DEVBASE_GIT_EMAIL DEVBASE_SSH_KEY_NAME
	export EDITOR VISUAL DEVBASE_VSCODE_INSTALL DEVBASE_VSCODE_EXTENSIONS
	export DEVBASE_INSTALL_LAZYVIM DEVBASE_INSTALL_INTELLIJ DEVBASE_INSTALL_JMC
	export DEVBASE_ZELLIJ_AUTOSTART DEVBASE_ENABLE_GIT_HOOKS DEVBASE_SELECTED_PACKS
	export DEVBASE_SSH_KEY_ACTION="skip"

	# Only show message in gum mode
	if [[ "${DEVBASE_TUI_MODE:-}" == "gum" ]]; then
		show_progress success "Preferences loaded from ${prefs_file/#$HOME/~}"
	fi
	# _yq_read is not truly local (bash has no local functions); clean up after use
	unset -f _yq_read
	return 0
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Brief: Generate default email from author name
# Params: $1 - author name, $2 - email domain (e.g., "@example.com")
# Outputs: Generated email to stdout
_generate_default_email_from_name() {
	local author_name="$1" email_domain="$2"
	if [[ -n "$email_domain" ]] && [[ "$email_domain" != "@" ]]; then
		echo "$author_name" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null |
			sed 's/ /./g' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z.' |
			sed "s/\$/${email_domain}/"
	fi
}

# Brief: Append email domain to variable if missing @
# Params: $1 - variable name (by reference), $2 - domain to append
_append_domain_if_needed() {
	local -n _email_ref="$1"
	local domain="$2"

	# Skip if domain is empty or just @
	[[ -z "$domain" || "$domain" == "@" ]] && return 0

	# Skip if already has @
	[[ "$_email_ref" == *@* ]] && return 0

	# Append domain
	_email_ref="${_email_ref}${domain}"
}

# Brief: Convert boolean to checkmark symbol
# Params: $1 - "true" or "false"
# Outputs: "✓" for true, "·" for false
_bool_to_symbol() {
	[[ "$1" == "true" ]] && printf '✓\n' || printf '·\n'
}

apply_preference_defaults() {
	[[ -z "$DEVBASE_THEME" ]] && DEVBASE_THEME="$(get_default_theme)"
	[[ -z "$DEVBASE_FONT" ]] && DEVBASE_FONT="$(get_default_font)"
	[[ -z "$DEVBASE_SSH_KEY_NAME" ]] && DEVBASE_SSH_KEY_NAME="$(get_default_ssh_key_name)"
	[[ -z "$EDITOR" ]] && EDITOR="$(get_default_editor)"
	[[ -z "$VISUAL" ]] && VISUAL="$EDITOR"

	if [[ "${_DEVBASE_ENV}" == "wsl-ubuntu" ]]; then
		[[ -z "$DEVBASE_VSCODE_INSTALL" ]] && DEVBASE_VSCODE_INSTALL="false"
	else
		[[ -z "$DEVBASE_VSCODE_INSTALL" ]] && DEVBASE_VSCODE_INSTALL="$(get_default_vscode_install)"
	fi

	[[ -z "$DEVBASE_VSCODE_EXTENSIONS" ]] && DEVBASE_VSCODE_EXTENSIONS="$(get_default_vscode_extensions)"
	[[ -z "$DEVBASE_INSTALL_DEVTOOLS" ]] && DEVBASE_INSTALL_DEVTOOLS="$(get_default_install_devtools)"
	[[ -z "$DEVBASE_INSTALL_LAZYVIM" ]] && DEVBASE_INSTALL_LAZYVIM="$(get_default_install_lazyvim)"
	[[ -z "$DEVBASE_INSTALL_INTELLIJ" ]] && DEVBASE_INSTALL_INTELLIJ="$(get_default_install_intellij)"
	[[ -z "$DEVBASE_INSTALL_JMC" ]] && DEVBASE_INSTALL_JMC="$(get_default_install_jmc)"
	[[ -z "$DEVBASE_ZELLIJ_AUTOSTART" ]] && DEVBASE_ZELLIJ_AUTOSTART="$(get_default_zellij_autostart)"
	[[ -z "$DEVBASE_ENABLE_GIT_HOOKS" ]] && DEVBASE_ENABLE_GIT_HOOKS="$(get_default_enable_git_hooks)"
	[[ -z "$DEVBASE_SELECTED_PACKS" ]] && DEVBASE_SELECTED_PACKS="$(get_default_packs)"
	return 0
}

# =============================================================================
# WRITE PREFERENCES
# =============================================================================

write_user_preferences() {
	local prefs_file="${DEVBASE_CONFIG_DIR}/preferences.yaml"
	mkdir -p "${DEVBASE_CONFIG_DIR}"

	# Determine shell_bindings value based on editor choice
	local shell_bindings
	shell_bindings=$([[ "${EDITOR:-}" == "nvim" ]] && printf 'vim' || printf 'emacs')

	# Write YAML using yq with env() to inject values safely.
	# Direct heredoc interpolation would corrupt YAML when values contain
	# special characters (`:`, `#`, `[`, `"`, leading `-`) — e.g. git author names.
	# Boolean fields use (env(VAR) == "true") to write unquoted YAML booleans.
	PREF_THEME="$DEVBASE_THEME" \
		PREF_FONT="$DEVBASE_FONT" \
		PREF_GIT_AUTHOR="${DEVBASE_GIT_AUTHOR:-}" \
		PREF_GIT_EMAIL="${DEVBASE_GIT_EMAIL:-}" \
		PREF_SSH_KEY_ACTION="${DEVBASE_SSH_KEY_ACTION:-}" \
		PREF_SSH_KEY_NAME="${DEVBASE_SSH_KEY_NAME:-}" \
		PREF_EDITOR="${EDITOR:-}" \
		PREF_SHELL_BINDINGS="$shell_bindings" \
		PREF_VSCODE_INSTALL="$DEVBASE_VSCODE_INSTALL" \
		PREF_VSCODE_EXTENSIONS="$DEVBASE_VSCODE_EXTENSIONS" \
		PREF_LAZYVIM="$DEVBASE_INSTALL_LAZYVIM" \
		PREF_INTELLIJ="$DEVBASE_INSTALL_INTELLIJ" \
		PREF_JMC="$DEVBASE_INSTALL_JMC" \
		PREF_ZELLIJ_AUTOSTART="$DEVBASE_ZELLIJ_AUTOSTART" \
		PREF_GIT_HOOKS="$DEVBASE_ENABLE_GIT_HOOKS" \
		PREF_PACKS="${DEVBASE_SELECTED_PACKS:-}" \
		yq --null-input '
		.theme                  = strenv(PREF_THEME) |
		.font                   = strenv(PREF_FONT) |
		.git.author             = strenv(PREF_GIT_AUTHOR) |
		.git.email              = strenv(PREF_GIT_EMAIL) |
		.ssh.key_action         = strenv(PREF_SSH_KEY_ACTION) |
		.ssh.key_name           = strenv(PREF_SSH_KEY_NAME) |
		.editor.default         = strenv(PREF_EDITOR) |
		.editor.shell_bindings  = strenv(PREF_SHELL_BINDINGS) |
		.vscode.install         = (strenv(PREF_VSCODE_INSTALL) == "true") |
		.vscode.extensions      = (strenv(PREF_VSCODE_EXTENSIONS) == "true") |
		.ide.lazyvim            = (strenv(PREF_LAZYVIM) == "true") |
		.ide.intellij           = (strenv(PREF_INTELLIJ) == "true") |
		.ide.jmc                = (strenv(PREF_JMC) == "true") |
		.tools.zellij_autostart = (strenv(PREF_ZELLIJ_AUTOSTART) == "true") |
		.tools.git_hooks        = (strenv(PREF_GIT_HOOKS) == "true") |
		.packs                  = (strenv(PREF_PACKS) | split(" ") | map(select(length > 0))) |
		.packs style            = "flow"
	' >"$prefs_file"

	# Call UI-specific success message if defined, otherwise use show_progress
	if declare -f _ui_success &>/dev/null; then
		_ui_success "Preferences saved to ${prefs_file/#$HOME/~}"
	else
		show_progress success "User preferences saved to ${prefs_file/#$HOME/~}"
	fi
}
