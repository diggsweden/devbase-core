#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

get_default_packs() {
  if [[ -n "${DEVBASE_DEFAULT_PACKS:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_PACKS"
  else
    printf "%s" "java node python go ruby"
  fi
}

get_default_theme() {
  if [[ -n "${DEVBASE_DEFAULT_THEME:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_THEME"
  else
    printf "%s" "everforest-dark"
  fi
}

get_default_font() {
  if [[ -n "${DEVBASE_DEFAULT_FONT:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_FONT"
  else
    printf "%s" "monaspace"
  fi
}

get_default_editor() {
  if [[ -n "${DEVBASE_DEFAULT_EDITOR:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_EDITOR"
  else
    printf "%s" "nvim"
  fi
}

get_default_vscode_install() {
  if [[ -n "${DEVBASE_DEFAULT_VSCODE_INSTALL:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_VSCODE_INSTALL"
  else
    printf "%s" "true"
  fi
}

get_default_vscode_extensions() {
  if [[ -n "${DEVBASE_DEFAULT_VSCODE_EXTENSIONS:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_VSCODE_EXTENSIONS"
  else
    printf "%s" "true"
  fi
}

get_default_install_devtools() {
  if [[ -n "${DEVBASE_DEFAULT_INSTALL_DEVTOOLS:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_INSTALL_DEVTOOLS"
  else
    printf "%s" "true"
  fi
}

get_default_install_lazyvim() {
  if [[ -n "${DEVBASE_DEFAULT_INSTALL_LAZYVIM:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_INSTALL_LAZYVIM"
  else
    printf "%s" "true"
  fi
}

get_default_install_intellij() {
  if [[ -n "${DEVBASE_DEFAULT_INSTALL_INTELLIJ:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_INSTALL_INTELLIJ"
  else
    printf "%s" "false"
  fi
}

get_default_install_jmc() {
  if [[ -n "${DEVBASE_DEFAULT_INSTALL_JMC:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_INSTALL_JMC"
  else
    printf "%s" "false"
  fi
}

get_default_zellij_autostart() {
  if [[ -n "${DEVBASE_DEFAULT_ZELLIJ_AUTOSTART:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_ZELLIJ_AUTOSTART"
  else
    printf "%s" "false"
  fi
}

get_default_enable_git_hooks() {
  if [[ -n "${DEVBASE_DEFAULT_ENABLE_GIT_HOOKS:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_ENABLE_GIT_HOOKS"
  else
    printf "%s" "true"
  fi
}

get_default_ssh_key_name() {
  if [[ -n "${DEVBASE_DEFAULT_SSH_KEY_NAME:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_SSH_KEY_NAME"
  else
    printf "%s" "id_ed25519_devbase"
  fi
}

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
