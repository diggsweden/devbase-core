#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2034,SC2153,SC2155
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export DEVBASE_CONFIG_DIR="${XDG_CONFIG_HOME}/devbase"
  export DEVBASE_THEME="everforest-dark"
  export DEVBASE_ZELLIJ_AUTOSTART="true"
  export DEVBASE_SSH_KEY_TYPE="ed25519"
  export DEVBASE_SSH_KEY_NAME="id_ed25519_devbase"
  export _DEVBASE_ENV="ubuntu"

  # Stub external tool binaries to avoid calling host tools
  mkdir -p "${TEST_DIR}/bin"
  for cmd in node python go ruby rustc java mvn gradle fish starship zellij \
    git nvim code lazygit rg fd fzf eza bat delta jq yq podman buildah \
    skopeo kubectl oc k9s mise; do
    cat > "${TEST_DIR}/bin/${cmd}" << 'SCRIPT'
#!/usr/bin/env bash
echo "stub"
SCRIPT
    chmod +x "${TEST_DIR}/bin/${cmd}"
  done
  export PATH="${TEST_DIR}/bin:${PATH}"

  # Ensure standard env vars are set for summary tests
  export USER="${USER:-testuser}"
  export SHELL="${SHELL:-/bin/bash}"

  mkdir -p "$DEVBASE_CONFIG_DIR"
  echo "1.0.0" >"${DEVBASE_CONFIG_DIR}/version"
}

teardown() {
  common_teardown
}

# Helper to source summary.sh with required dependencies
source_summary() {
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/distro.sh"
  source "${DEVBASE_ROOT}/libs/summary.sh"
}

@test "_summary_header outputs installation header" {
  source_summary

  run _summary_header
  assert_success
  assert_output --partial "DEVBASE INSTALLATION SUMMARY"
  assert_output --partial "Environment: ubuntu"
  assert_output --partial "Theme: everforest-dark"
}

@test "_summary_header includes devbase version" {
  source_summary

  run _summary_header
  assert_success
  assert_output --partial "DevBase Version: 1.0.0"
}

@test "_summary_system_config outputs system configuration" {
  source_summary

  run _summary_system_config
  assert_success
  assert_output --partial "SYSTEM CONFIGURATION"
  assert_output --partial "User:"
  assert_output --partial "Home:"
  assert_output --partial "Shell:"
  assert_output --partial "XDG_CONFIG_HOME:"
  assert_output --partial "XDG_DATA_HOME:"
}

@test "_summary_development_languages outputs languages section" {
  source_summary

  run _summary_development_languages
  assert_success
  assert_output --partial "DEVELOPMENT LANGUAGES (mise-managed)"
  assert_output --partial "Node.js:"
  assert_output --partial "Python:"
  assert_output --partial "Go:"
  assert_output --partial "Ruby:"
  assert_output --partial "Rust:"
  assert_output --partial "Java:"
  assert_output --partial "Maven:"
  assert_output --partial "Gradle:"
}

@test "_summary_shell_terminal outputs shell and terminal info" {
  source_summary

  run _summary_shell_terminal
  assert_success
  assert_output --partial "SHELL & TERMINAL"
  assert_output --partial "Fish:"
  assert_output --partial "Starship:"
  assert_output --partial "Zellij:"
  assert_output --partial "Zellij Autostart: true"
  assert_output --partial "Monaspace Nerd Font:"
}

@test "_summary_development_tools outputs dev tools section" {
  source_summary

  run _summary_development_tools
  assert_success
  assert_output --partial "DEVELOPMENT TOOLS"
  assert_output --partial "Git:"
  assert_output --partial "Neovim:"
  assert_output --partial "LazyVim:"
  assert_output --partial "VS Code:"
  assert_output --partial "Lazygit:"
  assert_output --partial "Ripgrep:"
  assert_output --partial "Fd:"
  assert_output --partial "Fzf:"
  assert_output --partial "Eza:"
  assert_output --partial "Bat:"
  assert_output --partial "Delta:"
  assert_output --partial "Jq:"
  assert_output --partial "Yq:"
}

@test "_summary_container_tools outputs container tools section" {
  source_summary

  run _summary_container_tools
  assert_success
  assert_output --partial "CONTAINER TOOLS"
  assert_output --partial "Podman:"
  assert_output --partial "Buildah:"
  assert_output --partial "Skopeo:"
}

@test "_summary_cloud_kubernetes outputs cloud and k8s section" {
  source_summary

  run _summary_cloud_kubernetes
  assert_success
  assert_output --partial "CLOUD & KUBERNETES"
  assert_output --partial "kubectl:"
  assert_output --partial "oc:"
  assert_output --partial "k9s:"
}

@test "_summary_optional_tools outputs optional tools section" {
  source_summary

  run _summary_optional_tools
  assert_success
  assert_output --partial "OPTIONAL TOOLS"
  assert_output --partial "DBeaver:"
  assert_output --partial "KeyStore Explorer:"
  assert_output --partial "IntelliJ IDEA:"
  assert_output --partial "JMC:"
}

@test "_summary_git_config outputs git configuration" {
  source_summary

  run _summary_git_config
  assert_success
  assert_output --partial "GIT CONFIGURATION"
  assert_output --partial "Name:"
  assert_output --partial "Email:"
  assert_output --partial "Default Branch:"
  assert_output --partial "GPG Sign:"
  assert_output --partial "SSH Sign:"
}

@test "_summary_ssh_config outputs SSH configuration" {
  source_summary

  run _summary_ssh_config
  assert_success
  assert_output --partial "SSH CONFIGURATION"
  assert_output --partial "Key Type: ED25519"
  assert_output --partial "Key Path: ${HOME}/.ssh/id_ed25519_devbase"
  assert_output --partial "Key Exists:"
  assert_output --partial "Public Key Exists:"
  assert_output --partial "SSH Agent:"
}

@test "_summary_ssh_config handles custom key type" {
  export DEVBASE_SSH_KEY_TYPE="rsa"
  export DEVBASE_SSH_KEY_NAME="id_rsa_custom"
  source_summary

  run _summary_ssh_config
  assert_success
  assert_output --partial "Key Type: RSA"
  assert_output --partial "Key Path: ${HOME}/.ssh/id_rsa_custom"
}

@test "_summary_network_config outputs network configuration without proxy" {
  source_summary

  run _summary_network_config
  assert_success
  assert_output --partial "NETWORK CONFIGURATION"
  assert_output --partial "Proxy: not configured"
  assert_output --partial "Registry: not configured"
}

@test "_summary_network_config outputs network configuration with proxy" {
  export DEVBASE_PROXY_HOST="proxy.example.com"
  export DEVBASE_PROXY_PORT="8080"
  export DEVBASE_REGISTRY_HOST="registry.example.com"
  export DEVBASE_REGISTRY_PORT="5000"
  source_summary

  run _summary_network_config
  assert_success
  assert_output --partial "Proxy: proxy.example.com:8080"
  assert_output --partial "Registry: registry.example.com:5000"
}

@test "_summary_mise_activation outputs mise activation info" {
  source_summary

  run _summary_mise_activation
  assert_success
  assert_output --partial "MISE ACTIVATION"
  assert_output --partial "Mise Version:"
  assert_output --partial "Config File:"
  assert_output --partial "Activation:"
}

@test "_summary_custom_config outputs custom configuration without custom dir" {
  source_summary

  run _summary_custom_config
  assert_success
  assert_output --partial "CUSTOM CONFIGURATION"
  assert_output --partial "Custom Dir: not configured (using defaults)"
  assert_output --partial "Custom Env: not loaded"
}

@test "_summary_custom_config outputs custom configuration with custom dir" {
  export DEVBASE_CUSTOM_DIR="${TEST_DIR}/custom"
  export DEVBASE_CUSTOM_ENV="loaded"
  source_summary

  run _summary_custom_config
  assert_success
  assert_output --partial "Custom Dir: ${TEST_DIR}/custom"
  assert_output --partial "Custom Env: loaded"
}

@test "_summary_next_steps outputs next steps" {
  source_summary

  run _summary_next_steps
  assert_success
  assert_output --partial "NEXT STEPS"
  assert_output --partial "Restart your shell"
  assert_output --partial "Verify installation"
  assert_output --partial "https://github.com/diggsweden/devbase-core"
}

@test "write_installation_summary creates summary file" {
  source_summary

  run write_installation_summary
  assert_success
  assert_file_exists "${DEVBASE_CONFIG_DIR}/install-summary.txt"
}

@test "write_installation_summary includes all sections" {
  source_summary
  write_installation_summary

  local summary_file="${DEVBASE_CONFIG_DIR}/install-summary.txt"
  assert_file_exists "$summary_file"

  # Verify all major sections are present
  run cat "$summary_file"
  assert_output --partial "DEVBASE INSTALLATION SUMMARY"
  assert_output --partial "SYSTEM CONFIGURATION"
  assert_output --partial "DEVELOPMENT LANGUAGES"
  assert_output --partial "SHELL & TERMINAL"
  assert_output --partial "DEVELOPMENT TOOLS"
  assert_output --partial "CONTAINER TOOLS"
  assert_output --partial "CLOUD & KUBERNETES"
  assert_output --partial "OPTIONAL TOOLS"
  assert_output --partial "GIT CONFIGURATION"
  assert_output --partial "SSH CONFIGURATION"
  assert_output --partial "NETWORK CONFIGURATION"
  assert_output --partial "MISE ACTIVATION"
  assert_output --partial "CUSTOM CONFIGURATION"
  assert_output --partial "NEXT STEPS"
}

@test "write_installation_summary fails without DEVBASE_CONFIG_DIR" {
  unset DEVBASE_CONFIG_DIR
  source_summary

  run write_installation_summary
  assert_failure
}

@test "write_installation_summary overwrites existing file" {
  source_summary
  echo "old content" >"${DEVBASE_CONFIG_DIR}/install-summary.txt"

  write_installation_summary

  local summary_file="${DEVBASE_CONFIG_DIR}/install-summary.txt"
  run cat "$summary_file"
  refute_output --partial "old content"
  assert_output --partial "DEVBASE INSTALLATION SUMMARY"
}
