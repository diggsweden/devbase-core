#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Each getter returns the value of the corresponding DEVBASE_DEFAULT_* variable.
# Defaults are loaded from config/defaults.env during setup (or constants.sh fallback).

# Brief: Return the default language pack selection
get_default_packs() { printf '%s' "$DEVBASE_DEFAULT_PACKS"; }

# Brief: Return the default colour theme
get_default_theme() { printf '%s' "$DEVBASE_DEFAULT_THEME"; }

# Brief: Return the default Nerd Font family
get_default_font() { printf '%s' "$DEVBASE_DEFAULT_FONT"; }

# Brief: Return the default terminal editor
get_default_editor() { printf '%s' "$DEVBASE_DEFAULT_EDITOR"; }

# Brief: Return whether VS Code should be installed by default
get_default_vscode_install() { printf '%s' "$DEVBASE_DEFAULT_VSCODE_INSTALL"; }

# Brief: Return whether VS Code extensions should be installed by default
get_default_vscode_extensions() { printf '%s' "$DEVBASE_DEFAULT_VSCODE_EXTENSIONS"; }

# Brief: Return whether dev tools (lazygit, etc.) should be installed by default
get_default_install_devtools() { printf '%s' "$DEVBASE_DEFAULT_INSTALL_DEVTOOLS"; }

# Brief: Return whether LazyVim should be installed by default
get_default_install_lazyvim() { printf '%s' "$DEVBASE_DEFAULT_INSTALL_LAZYVIM"; }

# Brief: Return whether IntelliJ IDEA should be installed by default
get_default_install_intellij() { printf '%s' "$DEVBASE_DEFAULT_INSTALL_INTELLIJ"; }

# Brief: Return whether JDK Mission Control should be installed by default
get_default_install_jmc() { printf '%s' "$DEVBASE_DEFAULT_INSTALL_JMC"; }

# Brief: Return whether Zellij should autostart by default
get_default_zellij_autostart() { printf '%s' "$DEVBASE_DEFAULT_ZELLIJ_AUTOSTART"; }

# Brief: Return whether Git hooks should be enabled by default
get_default_enable_git_hooks() { printf '%s' "$DEVBASE_DEFAULT_ENABLE_GIT_HOOKS"; }

# Brief: Return the default SSH key filename (without path)
get_default_ssh_key_name() { printf '%s' "$DEVBASE_DEFAULT_SSH_KEY_NAME"; }

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
