#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

init_context_array() {
  local name="$1"
  declare -gA "$name"
  eval "$name=()"
}

context_set() {
  local name="$1"
  local key="$2"
  local value="$3"
  # shellcheck disable=SC2178 # Nameref to associative array
  local -n ctx="$name"
  ctx["$key"]="$value"
}

context_get() {
  local name="$1"
  local key="$2"
  local fallback="${3:-}"
  # shellcheck disable=SC2178 # Nameref to associative array
  local -n ctx="$name"
  if [[ -n "${ctx[$key]:-}" ]]; then
    printf "%s" "${ctx[$key]}"
  else
    printf "%s" "$fallback"
  fi
}
