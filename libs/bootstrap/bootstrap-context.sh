#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# shellcheck disable=SC1091 # Loaded via DEVBASE_ROOT at runtime
source "${DEVBASE_ROOT}/libs/context.sh"

declare -Ag BOOTSTRAP_CONTEXT=()

init_bootstrap_context() {
  init_context_array BOOTSTRAP_CONTEXT
  context_set BOOTSTRAP_CONTEXT env_file "${_DEVBASE_ENV_FILE:-}"
  context_set BOOTSTRAP_CONTEXT custom_hooks_dir "${_DEVBASE_CUSTOM_HOOKS:-}"
  context_set BOOTSTRAP_CONTEXT custom_ssh_dir "${_DEVBASE_CUSTOM_SSH:-}"
}

set_bootstrap_env_file() {
  local env_file="$1"
  context_set BOOTSTRAP_CONTEXT env_file "$env_file"
}

set_bootstrap_custom_paths() {
  local base_dir="$1"
  context_set BOOTSTRAP_CONTEXT custom_dir "$base_dir"
  context_set BOOTSTRAP_CONTEXT custom_hooks_dir "${base_dir}/hooks"
  context_set BOOTSTRAP_CONTEXT custom_ssh_dir "${base_dir}/ssh"
  context_set BOOTSTRAP_CONTEXT custom_templates_dir "${base_dir}/templates"
}

get_bootstrap_env_file() {
  context_get BOOTSTRAP_CONTEXT env_file "${_DEVBASE_ENV_FILE:-}"
}

get_bootstrap_custom_hooks_dir() {
  context_get BOOTSTRAP_CONTEXT custom_hooks_dir "${_DEVBASE_CUSTOM_HOOKS:-}"
}

get_bootstrap_custom_ssh_dir() {
  context_get BOOTSTRAP_CONTEXT custom_ssh_dir "${_DEVBASE_CUSTOM_SSH:-}"
}
