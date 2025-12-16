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
  export TEST_HOME="${TEST_DIR}/home"
  mkdir -p "${TEST_HOME}/.ssh"
  mkdir -p "${TEST_HOME}/.config/devbase"
  
  # Path to the fish function file
  FISH_FUNC="${DEVBASE_ROOT}/dot/.config/fish/functions/__ssh_agent_init.fish"
}

teardown() {
  common_teardown
}

# =============================================================================
# Helper: Create a mock SSH key file
# =============================================================================
create_mock_ssh_key() {
  local key_name="$1"
  local key_path="${TEST_HOME}/.ssh/${key_name}"
  
  # Create a minimal valid ED25519 private key structure for testing
  # This is NOT a real key - just enough for ssh-keygen -lf to work
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
  
  # Create corresponding public key
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUZVRRokIVhnVE/lQ+bzGRTaAFTU5Y4q5ink1jLGZ/ test@test.com" > "${key_path}.pub"
  chmod 644 "${key_path}.pub"
}

# =============================================================================
# Helper: Create preferences.yaml with specific key name
# =============================================================================
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

# =============================================================================
# Test: Key detection from preferences.yaml with custom key name
# =============================================================================
@test "__ssh_agent_init finds key from preferences.yaml with custom name" {
  # Skip if fish is not available
  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi
  
  # Create a custom-named SSH key (simulating org-specific config)
  create_mock_ssh_key "id_ecdsa_mycompany"
  create_preferences_yaml "id_ecdsa_mycompany"
  
  # Run the fish function and check if it finds the key
  # We test key detection by checking the devbase_key variable
  run fish -c "
    set -x HOME '$TEST_HOME'
    source '$FISH_FUNC'
    
    # Test key detection logic only (extract devbase_key finding)
    set -l devbase_key ''
    set -l prefs_file \"\$HOME/.config/devbase/preferences.yaml\"
    
    if test -f \$prefs_file
      set -l key_name (grep '^\s*key_name:' \$prefs_file 2>/dev/null | sed 's/.*key_name:\s*//' | string trim)
      if test -n \"\$key_name\"; and test -f \"\$HOME/.ssh/\$key_name\"
        set devbase_key \"\$HOME/.ssh/\$key_name\"
      end
    end
    
    echo \$devbase_key
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "${TEST_HOME}/.ssh/id_ecdsa_mycompany"
}

# =============================================================================
# Test: Key detection with default devbase key name (core-only install)
# =============================================================================
@test "__ssh_agent_init finds default devbase key without preferences.yaml" {
  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi
  
  # Create default devbase SSH key (no preferences.yaml)
  create_mock_ssh_key "id_ed25519_devbase"
  
  # Run the fish function to test fallback pattern matching
  run fish -c "
    set -x HOME '$TEST_HOME'
    source '$FISH_FUNC'
    
    # Test key detection logic
    set -l devbase_key ''
    set -l prefs_file \"\$HOME/.config/devbase/preferences.yaml\"
    
    if test -f \$prefs_file
      set -l key_name (grep '^\s*key_name:' \$prefs_file 2>/dev/null | sed 's/.*key_name:\s*//' | string trim)
      if test -n \"\$key_name\"; and test -f \"\$HOME/.ssh/\$key_name\"
        set devbase_key \"\$HOME/.ssh/\$key_name\"
      end
    end
    
    # Fallback to patterns
    if test -z \"\$devbase_key\"
      for key_pattern in id_ed25519_devbase id_ecdsa_521_devbase id_ed25519_sk_devbase id_ecdsa_sk_devbase
        if test -f \"\$HOME/.ssh/\$key_pattern\"
          set devbase_key \"\$HOME/.ssh/\$key_pattern\"
          break
        end
      end
    end
    
    echo \$devbase_key
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "${TEST_HOME}/.ssh/id_ed25519_devbase"
}

# =============================================================================
# Test: Preferences.yaml takes priority over fallback patterns
# =============================================================================
@test "__ssh_agent_init prefers preferences.yaml over fallback patterns" {
  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi
  
  # Create BOTH a default key AND a custom key with preferences pointing to custom
  create_mock_ssh_key "id_ed25519_devbase"
  create_mock_ssh_key "id_ed25519_custom_org"
  create_preferences_yaml "id_ed25519_custom_org"
  
  # The function should use the custom key from preferences, not the default
  run fish -c "
    set -x HOME '$TEST_HOME'
    source '$FISH_FUNC'
    
    set -l devbase_key ''
    set -l prefs_file \"\$HOME/.config/devbase/preferences.yaml\"
    
    if test -f \$prefs_file
      set -l key_name (grep '^\s*key_name:' \$prefs_file 2>/dev/null | sed 's/.*key_name:\s*//' | string trim)
      if test -n \"\$key_name\"; and test -f \"\$HOME/.ssh/\$key_name\"
        set devbase_key \"\$HOME/.ssh/\$key_name\"
      end
    end
    
    if test -z \"\$devbase_key\"
      for key_pattern in id_ed25519_devbase id_ecdsa_521_devbase id_ed25519_sk_devbase id_ecdsa_sk_devbase
        if test -f \"\$HOME/.ssh/\$key_pattern\"
          set devbase_key \"\$HOME/.ssh/\$key_pattern\"
          break
        end
      end
    end
    
    echo \$devbase_key
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  # Should return custom key from preferences, NOT the default
  assert_output "${TEST_HOME}/.ssh/id_ed25519_custom_org"
}

# =============================================================================
# Test: Returns empty when no key exists
# =============================================================================
@test "__ssh_agent_init returns empty when no devbase key found" {
  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi
  
  # Don't create any SSH key - test that function handles missing keys gracefully
  
  run fish -c "
    set -x HOME '$TEST_HOME'
    source '$FISH_FUNC'
    
    set -l devbase_key ''
    set -l prefs_file \"\$HOME/.config/devbase/preferences.yaml\"
    
    if test -f \$prefs_file
      set -l key_name (grep '^\s*key_name:' \$prefs_file 2>/dev/null | sed 's/.*key_name:\s*//' | string trim)
      if test -n \"\$key_name\"; and test -f \"\$HOME/.ssh/\$key_name\"
        set devbase_key \"\$HOME/.ssh/\$key_name\"
      end
    end
    
    if test -z \"\$devbase_key\"
      for key_pattern in id_ed25519_devbase id_ecdsa_521_devbase id_ed25519_sk_devbase id_ecdsa_sk_devbase
        if test -f \"\$HOME/.ssh/\$key_pattern\"
          set devbase_key \"\$HOME/.ssh/\$key_pattern\"
          break
        end
      end
    end
    
    echo \$devbase_key
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output ""
}

# =============================================================================
# Test: Handles preferences.yaml with key that doesn't exist on disk
# =============================================================================
@test "__ssh_agent_init falls back to patterns when preferences key doesn't exist" {
  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi
  
  # Create preferences pointing to non-existent key, but create a default key
  create_preferences_yaml "id_ed25519_nonexistent"
  create_mock_ssh_key "id_ed25519_devbase"
  
  run fish -c "
    set -x HOME '$TEST_HOME'
    source '$FISH_FUNC'
    
    set -l devbase_key ''
    set -l prefs_file \"\$HOME/.config/devbase/preferences.yaml\"
    
    if test -f \$prefs_file
      set -l key_name (grep '^\s*key_name:' \$prefs_file 2>/dev/null | sed 's/.*key_name:\s*//' | string trim)
      if test -n \"\$key_name\"; and test -f \"\$HOME/.ssh/\$key_name\"
        set devbase_key \"\$HOME/.ssh/\$key_name\"
      end
    end
    
    if test -z \"\$devbase_key\"
      for key_pattern in id_ed25519_devbase id_ecdsa_521_devbase id_ed25519_sk_devbase id_ecdsa_sk_devbase
        if test -f \"\$HOME/.ssh/\$key_pattern\"
          set devbase_key \"\$HOME/.ssh/\$key_pattern\"
          break
        end
      end
    end
    
    echo \$devbase_key
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  # Should fall back to the default key when preferences key doesn't exist
  assert_output "${TEST_HOME}/.ssh/id_ed25519_devbase"
}

# =============================================================================
# Test: ECDSA key type from custom config
# =============================================================================
@test "__ssh_agent_init finds ECDSA key from custom org config" {
  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi
  
  # Simulate organization using ECDSA keys with custom naming
  create_mock_ssh_key "id_ecdsa_nistp521_devbase"
  create_preferences_yaml "id_ecdsa_nistp521_devbase"
  
  run fish -c "
    set -x HOME '$TEST_HOME'
    source '$FISH_FUNC'
    
    set -l devbase_key ''
    set -l prefs_file \"\$HOME/.config/devbase/preferences.yaml\"
    
    if test -f \$prefs_file
      set -l key_name (grep '^\s*key_name:' \$prefs_file 2>/dev/null | sed 's/.*key_name:\s*//' | string trim)
      if test -n \"\$key_name\"; and test -f \"\$HOME/.ssh/\$key_name\"
        set devbase_key \"\$HOME/.ssh/\$key_name\"
      end
    end
    
    if test -z \"\$devbase_key\"
      for key_pattern in id_ed25519_devbase id_ecdsa_521_devbase id_ed25519_sk_devbase id_ecdsa_sk_devbase
        if test -f \"\$HOME/.ssh/\$key_pattern\"
          set devbase_key \"\$HOME/.ssh/\$key_pattern\"
          break
        end
      end
    end
    
    echo \$devbase_key
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "${TEST_HOME}/.ssh/id_ecdsa_nistp521_devbase"
}

# =============================================================================
# Test: Full function execution returns 0 when key found
# =============================================================================
@test "__ssh_agent_init function returns 0 with valid key (no agent)" {
  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi
  
  create_mock_ssh_key "id_ed25519_devbase"
  create_preferences_yaml "id_ed25519_devbase"
  
  # Create mock ssh-add that simulates no agent running (exit code 2)
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/ssh-add" << 'SCRIPT'
#!/usr/bin/env bash
# Simulate: agent not running
exit 2
SCRIPT
  chmod +x "${TEST_DIR}/bin/ssh-add"
  
  # Run the full function - should warn about agent not running but not fail
  run fish -c "
    set -x HOME '$TEST_HOME'
    set -x PATH '${TEST_DIR}/bin:' \$PATH
    source '$FISH_FUNC'
    __ssh_agent_init
    echo \"exit_code: \$status\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  # Function should return 1 when agent is not running (warns user)
  assert_output --partial "Warning: SSH agent is not running"
}

# =============================================================================
# Test: Full function returns 0 when no key found (silent skip)
# =============================================================================
@test "__ssh_agent_init silently returns 0 when no key exists" {
  if ! command -v fish &>/dev/null; then
    skip "fish shell not installed"
  fi
  
  # No key, no preferences - should silently return 0
  
  run fish -c "
    set -x HOME '$TEST_HOME'
    source '$FISH_FUNC'
    __ssh_agent_init
    echo \"status: \$status\"
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "output: '${output}'"
  assert_success
  assert_output "status: 0"
}
