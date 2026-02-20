#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for __ssh_agent_init.fish function
# This function auto-adds devbase SSH key to ssh-agent on shell startup

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup

  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi

  export TEST_HOME="${TEST_DIR}/home"
  mkdir -p "${TEST_HOME}/.ssh"
  mkdir -p "${TEST_HOME}/.config/devbase"

  FISH_FUNC="${DEVBASE_ROOT}/dot/.config/fish/functions/__ssh_agent_init.fish"

  # Shared key-detection script used by detection tests.
  # Written to a file to avoid bash double-quote escaping noise.
  cat > "${TEST_DIR}/detect_key.fish" <<'FISH'
set -l devbase_key ""
set -l prefs_file "$HOME/.config/devbase/preferences.yaml"

if test -f $prefs_file
    set -l key_name (grep '^\s*key_name:' $prefs_file 2>/dev/null | sed 's/.*key_name:\s*//' | string trim)
    if test -n "$key_name"; and test -f "$HOME/.ssh/$key_name"
        set devbase_key "$HOME/.ssh/$key_name"
    end
end

if test -z "$devbase_key"
    for key_pattern in id_ed25519_devbase id_ecdsa_521_devbase id_ed25519_sk_devbase id_ecdsa_sk_devbase
        if test -f "$HOME/.ssh/$key_pattern"
            set devbase_key "$HOME/.ssh/$key_pattern"
            break
        end
    end
end

echo $devbase_key
FISH
}

teardown() {
  common_teardown
}

# Helper: Create a mock SSH key file
create_mock_ssh_key() {
  local key_name="$1"
  local key_path="${TEST_HOME}/.ssh/${key_name}"

  # gitleaks:allow - dummy test key, not a real secret
  cat > "${key_path}" << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBFGVdEEaJCFYZ1RP5UPm8xkU2gBU1OWOKuYp5NYyxmfwAAAJDhXoqJ4V6K
iQAAAAtzc2gtZWQyNTUxOQAAACBFGVdEEaJCFYZ1RP5UPm8xkU2gBU1OWOKuYp5NYyxmfw
AAAEDsVKGYvkDn8RfZdSyT2EK9fGlD6S8R5Q6Q0eUGcfUCYUUZV0QRokIVhnVE/lQ+bzGR
TaAFTU5Y4q5ink1jLGZ/AAAADnRlc3RAdGVzdC5jb20BAgMEBQY=
-----END OPENSSH PRIVATE KEY-----
EOF
  chmod 600 "${key_path}"
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUZVRRokIVhnVE/lQ+bzGRTaAFTU5Y4q5ink1jLGZ/ test@test.com" > "${key_path}.pub"
  chmod 644 "${key_path}.pub"
}

# Helper: Create preferences.yaml with specific key name
create_preferences_yaml() {
  local key_name="$1"
  cat > "${TEST_HOME}/.config/devbase/preferences.yaml" << EOF
# DevBase User Preferences
theme: everforest-dark
font: monaspace

git:
  author: Test User
  email: test@test.com

ssh:
  key_action: new
  key_name: ${key_name}

editor:
  default: nvim
  shell_bindings: vim
EOF
}

@test "__ssh_agent_init finds key from preferences.yaml with custom name" {
  create_mock_ssh_key "id_ecdsa_mycompany"
  create_preferences_yaml "id_ecdsa_mycompany"

  run env HOME="${TEST_HOME}" fish "${TEST_DIR}/detect_key.fish"

  assert_success
  assert_output "${TEST_HOME}/.ssh/id_ecdsa_mycompany"
}

@test "__ssh_agent_init finds default devbase key without preferences.yaml" {
  create_mock_ssh_key "id_ed25519_devbase"

  run env HOME="${TEST_HOME}" fish "${TEST_DIR}/detect_key.fish"

  assert_success
  assert_output "${TEST_HOME}/.ssh/id_ed25519_devbase"
}

@test "__ssh_agent_init prefers preferences.yaml over fallback patterns" {
  create_mock_ssh_key "id_ed25519_devbase"
  create_mock_ssh_key "id_ed25519_custom_org"
  create_preferences_yaml "id_ed25519_custom_org"

  run env HOME="${TEST_HOME}" fish "${TEST_DIR}/detect_key.fish"

  assert_success
  assert_output "${TEST_HOME}/.ssh/id_ed25519_custom_org"
}

@test "__ssh_agent_init returns empty when no devbase key found" {
  run env HOME="${TEST_HOME}" fish "${TEST_DIR}/detect_key.fish"

  assert_success
  assert_output ""
}

@test "__ssh_agent_init falls back to patterns when preferences key doesn't exist" {
  create_preferences_yaml "id_ed25519_nonexistent"
  create_mock_ssh_key "id_ed25519_devbase"

  run env HOME="${TEST_HOME}" fish "${TEST_DIR}/detect_key.fish"

  assert_success
  assert_output "${TEST_HOME}/.ssh/id_ed25519_devbase"
}

@test "__ssh_agent_init finds ECDSA key from custom org config" {
  create_mock_ssh_key "id_ecdsa_nistp521_devbase"
  create_preferences_yaml "id_ecdsa_nistp521_devbase"

  run env HOME="${TEST_HOME}" fish "${TEST_DIR}/detect_key.fish"

  assert_success
  assert_output "${TEST_HOME}/.ssh/id_ecdsa_nistp521_devbase"
}

@test "__ssh_agent_init function returns 0 with valid key (no agent)" {
  create_mock_ssh_key "id_ed25519_devbase"
  create_preferences_yaml "id_ed25519_devbase"

  # Mock ssh-add simulating no agent running (exit code 2)
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/ssh-add" << 'SCRIPT'
#!/usr/bin/env bash
exit 2
SCRIPT
  chmod +x "${TEST_DIR}/bin/ssh-add"

  run fish -c "
    set -x HOME '$TEST_HOME'
    set -x PATH '${TEST_DIR}/bin:' \$PATH
    source '$FISH_FUNC'
    __ssh_agent_init
    echo \"exit_code: \$status\"
  "

  assert_output --partial "Warning: SSH agent is not running"
}

@test "__ssh_agent_init silently returns 0 when no key exists" {
  run fish -c "
    set -x HOME '$TEST_HOME'
    source '$FISH_FUNC'
    __ssh_agent_init
    echo \"status: \$status\"
  "

  assert_success
  assert_output "status: 0"
}
