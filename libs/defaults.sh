#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Each getter returns the value of the corresponding DEVBASE_DEFAULT_* override
# when set, otherwise the built-in fallback.  The pattern is simply:
#   printf '%s' "${DEVBASE_DEFAULT_X:-fallback}"
# which is equivalent to the previous 5-line if/else but with no redundancy.

# Brief: Return the default language pack selection
# Returns: $DEVBASE_DEFAULT_PACKS or "java node python go ruby"
get_default_packs() { printf '%s' "${DEVBASE_DEFAULT_PACKS:-java node python go ruby}"; }

# Brief: Return the default colour theme
# Returns: $DEVBASE_DEFAULT_THEME or "everforest-dark"
get_default_theme() { printf '%s' "${DEVBASE_DEFAULT_THEME:-everforest-dark}"; }

# Brief: Return the default Nerd Font family
# Returns: $DEVBASE_DEFAULT_FONT or "monaspace"
get_default_font() { printf '%s' "${DEVBASE_DEFAULT_FONT:-monaspace}"; }

# Brief: Return the default terminal editor
# Returns: $DEVBASE_DEFAULT_EDITOR or "nvim"
get_default_editor() { printf '%s' "${DEVBASE_DEFAULT_EDITOR:-nvim}"; }

# Brief: Return whether VS Code should be installed by default
# Returns: $DEVBASE_DEFAULT_VSCODE_INSTALL or "true"
get_default_vscode_install() { printf '%s' "${DEVBASE_DEFAULT_VSCODE_INSTALL:-true}"; }

# Brief: Return whether VS Code extensions should be installed by default
# Returns: $DEVBASE_DEFAULT_VSCODE_EXTENSIONS or "true"
get_default_vscode_extensions() { printf '%s' "${DEVBASE_DEFAULT_VSCODE_EXTENSIONS:-true}"; }

# Brief: Return whether dev tools (lazygit, etc.) should be installed by default
# Returns: $DEVBASE_DEFAULT_INSTALL_DEVTOOLS or "true"
get_default_install_devtools() { printf '%s' "${DEVBASE_DEFAULT_INSTALL_DEVTOOLS:-true}"; }

# Brief: Return whether LazyVim should be installed by default
# Returns: $DEVBASE_DEFAULT_INSTALL_LAZYVIM or "true"
get_default_install_lazyvim() { printf '%s' "${DEVBASE_DEFAULT_INSTALL_LAZYVIM:-true}"; }

# Brief: Return whether IntelliJ IDEA should be installed by default
# Returns: $DEVBASE_DEFAULT_INSTALL_INTELLIJ or "false"
get_default_install_intellij() { printf '%s' "${DEVBASE_DEFAULT_INSTALL_INTELLIJ:-false}"; }

# Brief: Return whether JDK Mission Control should be installed by default
# Returns: $DEVBASE_DEFAULT_INSTALL_JMC or "false"
get_default_install_jmc() { printf '%s' "${DEVBASE_DEFAULT_INSTALL_JMC:-false}"; }

# Brief: Return whether Zellij should autostart by default
# Returns: $DEVBASE_DEFAULT_ZELLIJ_AUTOSTART or "false"
get_default_zellij_autostart() { printf '%s' "${DEVBASE_DEFAULT_ZELLIJ_AUTOSTART:-false}"; }

# Brief: Return whether Git hooks should be enabled by default
# Returns: $DEVBASE_DEFAULT_ENABLE_GIT_HOOKS or "true"
get_default_enable_git_hooks() { printf '%s' "${DEVBASE_DEFAULT_ENABLE_GIT_HOOKS:-true}"; }

# Brief: Return the default SSH key filename (without path)
# Returns: $DEVBASE_DEFAULT_SSH_KEY_NAME or "id_ed25519_devbase"
get_default_ssh_key_name() { printf '%s' "${DEVBASE_DEFAULT_SSH_KEY_NAME:-id_ed25519_devbase}"; }

apply_setup_defaults() {
  DEVBASE_THEME="${DEVBASE_THEME:-$(get_default_theme)}"
  DEVBASE_FONT="${DEVBASE_FONT:-$(get_default_font)}"
  DEVBASE_INSTALL_DEVTOOLS="${DEVBASE_INSTALL_DEVTOOLS:-$(get_default_install_devtools)}"
  DEVBASE_INSTALL_LAZYVIM="${DEVBASE_INSTALL_LAZYVIM:-$(get_default_install_lazyvim)}"
  DEVBASE_INSTALL_INTELLIJ="${DEVBASE_INSTALL_INTELLIJ:-$(get_default_install_intellij)}"
  DEVBASE_INSTALL_JMC="${DEVBASE_INSTALL_JMC:-$(get_default_install_jmc)}"
  DEVBASE_ZELLIJ_AUTOSTART="${DEVBASE_ZELLIJ_AUTOSTART:-$(get_default_zellij_autostart)}"
  DEVBASE_ENABLE_GIT_HOOKS="${DEVBASE_ENABLE_GIT_HOOKS:-$(get_default_enable_git_hooks)}"
  DEVBASE_SSH_KEY_NAME="${DEVBASE_SSH_KEY_NAME:-$(get_default_ssh_key_name)}"
  EDITOR="${EDITOR:-$(get_default_editor)}"
  VISUAL="${VISUAL:-$EDITOR}"
  export EDITOR VISUAL
}

# Brief: Return the default git author name
# Params: None
# Returns: $DEVBASE_DEFAULT_GIT_AUTHOR, then global git config user.name, or empty
get_default_git_author() {
  if [[ -n "${DEVBASE_DEFAULT_GIT_AUTHOR:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_GIT_AUTHOR"
    return 0
  fi
  if command -v git &>/dev/null; then
    local author
    author=$(git config --global user.name 2>/dev/null || true)
    [[ -n "$author" ]] && printf "%s" "$author"
  fi
}

# Brief: Return the default git author email
# Params: None
# Returns: $DEVBASE_DEFAULT_GIT_EMAIL, then global git config user.email, or empty
get_default_git_email() {
  if [[ -n "${DEVBASE_DEFAULT_GIT_EMAIL:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_GIT_EMAIL"
    return 0
  fi
  if command -v git &>/dev/null; then
    local email
    email=$(git config --global user.email 2>/dev/null || true)
    [[ -n "$email" ]] && printf "%s" "$email"
  fi
}
