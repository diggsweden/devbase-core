#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2030,SC2031
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT

# Tests for libs/migrations.sh

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
  mkdir -p "${HOME}/.config/devbase"
}

teardown() {
  common_teardown
}

@test "migrate_legacy_package_files removes apt-packages.txt" {
  touch "${HOME}/.config/devbase/apt-packages.txt"
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run migrate_legacy_package_files
  
  assert_success
  assert_file_not_exists "${HOME}/.config/devbase/apt-packages.txt"
}

@test "migrate_legacy_package_files removes snap-packages.txt" {
  touch "${HOME}/.config/devbase/snap-packages.txt"
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run migrate_legacy_package_files
  
  assert_success
  assert_file_not_exists "${HOME}/.config/devbase/snap-packages.txt"
}

@test "migrate_legacy_package_files removes custom-tools.yaml" {
  touch "${HOME}/.config/devbase/custom-tools.yaml"
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run migrate_legacy_package_files
  
  assert_success
  assert_file_not_exists "${HOME}/.config/devbase/custom-tools.yaml"
}

@test "migrate_legacy_package_files removes vscode-extensions.yaml" {
  touch "${HOME}/.config/devbase/vscode-extensions.yaml"
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run migrate_legacy_package_files
  
  assert_success
  assert_file_not_exists "${HOME}/.config/devbase/vscode-extensions.yaml"
}

@test "migrate_legacy_package_files removes all legacy files at once" {
  touch "${HOME}/.config/devbase/apt-packages.txt"
  touch "${HOME}/.config/devbase/snap-packages.txt"
  touch "${HOME}/.config/devbase/custom-tools.yaml"
  touch "${HOME}/.config/devbase/vscode-extensions.yaml"
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run migrate_legacy_package_files
  
  assert_success
  assert_file_not_exists "${HOME}/.config/devbase/apt-packages.txt"
  assert_file_not_exists "${HOME}/.config/devbase/snap-packages.txt"
  assert_file_not_exists "${HOME}/.config/devbase/custom-tools.yaml"
  assert_file_not_exists "${HOME}/.config/devbase/vscode-extensions.yaml"
}

@test "migrate_legacy_package_files succeeds when no legacy files exist" {
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run migrate_legacy_package_files
  
  assert_success
}

@test "migrate_legacy_package_files preserves packages.yaml" {
  echo "core: {}" > "${HOME}/.config/devbase/packages.yaml"
  touch "${HOME}/.config/devbase/apt-packages.txt"
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run migrate_legacy_package_files
  
  assert_success
  assert_file_exists "${HOME}/.config/devbase/packages.yaml"
  assert_file_not_exists "${HOME}/.config/devbase/apt-packages.txt"
}

@test "migrate_legacy_package_files preserves other config files" {
  echo "theme: gruvbox" > "${HOME}/.config/devbase/preferences.yaml"
  touch "${HOME}/.config/devbase/apt-packages.txt"
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run migrate_legacy_package_files
  
  assert_success
  assert_file_exists "${HOME}/.config/devbase/preferences.yaml"
}

@test "run_migrations calls migrate_legacy_package_files" {
  touch "${HOME}/.config/devbase/apt-packages.txt"
  source "${DEVBASE_ROOT}/libs/migrations.sh"
  
  run run_migrations
  
  assert_success
  assert_file_not_exists "${HOME}/.config/devbase/apt-packages.txt"
}

@test "migrate_git_signature_hook removes pre-push signature hook" {
  local hooks_dir="${HOME}/.config/git/git-hooks/pre-push.d"
  mkdir -p "$hooks_dir"
  touch "${hooks_dir}/01-verify-signatures.sh"
  source "${DEVBASE_ROOT}/libs/migrations.sh"

  run migrate_git_signature_hook

  assert_success
  assert_file_not_exists "${hooks_dir}/01-verify-signatures.sh"
}

@test "migrate_deployed_hooks_templates removes stale hooks-templates directory" {
  local templates_dir="${HOME}/.config/git/hooks-templates"
  mkdir -p "${templates_dir}/pre-push.d"
  touch "${templates_dir}/pre-push.d/01-verify-signatures.sh"
  mkdir -p "${templates_dir}/commit-msg.d"
  touch "${templates_dir}/commit-msg.d/01-conventional-commits.sh"
  source "${DEVBASE_ROOT}/libs/migrations.sh"

  run migrate_deployed_hooks_templates

  assert_success
  assert_file_not_exists "${templates_dir}"
}

@test "migrate_deployed_hooks_templates succeeds when directory does not exist" {
  source "${DEVBASE_ROOT}/libs/migrations.sh"

  run migrate_deployed_hooks_templates

  assert_success
}

@test "migrate_deployed_vscode_settings removes stale vscode directory" {
  local vscode_dir="${HOME}/.config/vscode"
  mkdir -p "${vscode_dir}"
  echo '{}' > "${vscode_dir}/settings.json"
  source "${DEVBASE_ROOT}/libs/migrations.sh"

  run migrate_deployed_vscode_settings

  assert_success
  assert_file_not_exists "${vscode_dir}"
}

@test "migrate_deployed_vscode_settings succeeds when directory does not exist" {
  source "${DEVBASE_ROOT}/libs/migrations.sh"

  run migrate_deployed_vscode_settings

  assert_success
}
