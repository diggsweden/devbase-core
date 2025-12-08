#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBS_DIR="${SCRIPT_DIR}/libs"

declare -A BATS_LIBS=(
  ["bats-support"]="https://github.com/bats-core/bats-support.git:v0.3.0"
  ["bats-assert"]="https://github.com/bats-core/bats-assert.git:v2.1.0"
  ["bats-file"]="https://github.com/bats-core/bats-file.git:v0.4.0"
  ["bats-mock"]="https://github.com/jasonkarns/bats-mock.git:"
)

ensure_libs_dir() {
  mkdir -p "$LIBS_DIR"
}

install_lib() {
  local name="$1"
  local url="${2%%:*}"
  local version="${2#*:}"
  local target_dir="${LIBS_DIR}/${name}"

  if [[ -d "$target_dir" ]]; then
    echo "Updating ${name}..."
    git -C "$target_dir" pull --quiet
  else
    echo "Installing ${name}..."
    if [[ -n "$version" ]]; then
      git clone --depth 1 --branch "$version" "$url" "$target_dir"
    else
      git clone --depth 1 "$url" "$target_dir"
    fi
  fi
}

install_all_libs() {
  for name in "${!BATS_LIBS[@]}"; do
    install_lib "$name" "${BATS_LIBS[$name]}"
  done
}

main() {
  ensure_libs_dir
  install_all_libs
  echo "BATS libraries installed in ${LIBS_DIR}"
}

main "$@"
