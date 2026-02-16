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

get_default_vscode_extensions() {
  if [[ -n "${DEVBASE_DEFAULT_VSCODE_EXTENSIONS:-}" ]]; then
    printf "%s" "$DEVBASE_DEFAULT_VSCODE_EXTENSIONS"
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
