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
