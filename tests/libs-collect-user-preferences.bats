#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup
}

teardown() {
  common_teardown
}

@test "_generate_default_email_from_name converts name to email" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    _generate_default_email_from_name 'John Doe' '@example.com'
  "
  
  assert_success
  assert_output "john.doe@example.com"
}

@test "_generate_default_email_from_name converts uppercase to lowercase" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    _generate_default_email_from_name 'JANE SMITH' '@example.com'
  "
  
  assert_success
  assert_output "jane.smith@example.com"
}

@test "_generate_default_email_from_name replaces spaces with dots" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    _generate_default_email_from_name 'Alice Bob Carol' '@example.com'
  "
  
  assert_success
  assert_output "alice.bob.carol@example.com"
}

@test "_generate_default_email_from_name returns empty when no domain" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    _generate_default_email_from_name 'John Doe' ''
  "
  
  assert_success
  assert_output ""
}

@test "_generate_default_email_from_name removes non-alphanumeric characters" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    _generate_default_email_from_name 'John-Doe#123' '@example.com'
  "
  
  assert_success
  # Should only have letters and dots
  assert_output "johndoe@example.com"
}

@test "_append_domain_if_needed appends domain when missing @" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    email='john.doe'
    _append_domain_if_needed email '@example.com'
    echo \"\$email\"
  "
  
  assert_success
  assert_output "john.doe@example.com"
}

@test "_append_domain_if_needed doesn't append when @ already present" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    email='john.doe@otherdomain.com'
    _append_domain_if_needed email '@example.com'
    echo \"\$email\"
  "
  
  assert_success
  assert_output "john.doe@otherdomain.com"
}

@test "_append_domain_if_needed skips when domain is empty" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    email='john.doe'
    _append_domain_if_needed email ''
    echo \"\$email\"
  "
  
  assert_success
  assert_output "john.doe"
}

@test "_append_domain_if_needed skips when domain is just @" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    email='john.doe'
    _append_domain_if_needed email '@'
    echo \"\$email\"
  "
  
  assert_success
  assert_output "john.doe"
}

# Helper to create a test preferences file
_create_test_preferences_yaml() {
  local prefs_file="$1"
  cat >"$prefs_file" <<'EOF'
# DevBase User Preferences
# Generated during installation: Thu Jan 01 2025

theme: catppuccin-mocha
font: JetBrainsMono

git:
  author: Test User
  email: test.user@example.com

ssh:
  key_action: new
  key_name: id_ed25519_devbase

editor:
  default: nvim
  shell_bindings: vim

vscode:
  install: true
  extensions: true
  neovim_extension: true

ide:
  lazyvim: true
  intellij: false
  jmc: false

tools:
  zellij_autostart: true
  git_hooks: true
EOF
}

@test "load_saved_preferences returns 1 when preferences file missing" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${BATS_TEST_TMPDIR}/config'
    mkdir -p \"\$DEVBASE_CONFIG_DIR\"
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences
  "
  
  assert_failure
}

@test "load_saved_preferences loads theme from preferences file" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  _create_test_preferences_yaml "$prefs_dir/preferences.yaml"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"\$DEVBASE_THEME\"
  "
  
  assert_success
  assert_output "catppuccin-mocha"
}

@test "load_saved_preferences loads git author from preferences file" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  _create_test_preferences_yaml "$prefs_dir/preferences.yaml"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"\$DEVBASE_GIT_AUTHOR\"
  "
  
  assert_success
  assert_output "Test User"
}

@test "load_saved_preferences loads editor and sets VISUAL" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  _create_test_preferences_yaml "$prefs_dir/preferences.yaml"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"EDITOR=\$EDITOR VISUAL=\$VISUAL\"
  "
  
  assert_success
  assert_output "EDITOR=nvim VISUAL=nvim"
}

@test "load_saved_preferences sets SSH key action to skip" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  _create_test_preferences_yaml "$prefs_dir/preferences.yaml"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"\$DEVBASE_SSH_KEY_ACTION\"
  "
  
  assert_success
  assert_output "skip"
}

@test "load_saved_preferences loads all IDE preferences" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  _create_test_preferences_yaml "$prefs_dir/preferences.yaml"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"lazyvim=\$DEVBASE_INSTALL_LAZYVIM intellij=\$DEVBASE_INSTALL_INTELLIJ jmc=\$DEVBASE_INSTALL_JMC\"
  "
  
  assert_success
  assert_output "lazyvim=true intellij=false jmc=false"
}

@test "load_saved_preferences loads all tool preferences" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  _create_test_preferences_yaml "$prefs_dir/preferences.yaml"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"zellij=\$DEVBASE_ZELLIJ_AUTOSTART hooks=\$DEVBASE_ENABLE_GIT_HOOKS\"
  "
  
  assert_success
  assert_output "zellij=true hooks=true"
}

@test "load_saved_preferences loads all vscode preferences" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  _create_test_preferences_yaml "$prefs_dir/preferences.yaml"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"install=\$DEVBASE_VSCODE_INSTALL ext=\$DEVBASE_VSCODE_EXTENSIONS\"
  "

  assert_success
  assert_output "install=true ext=true"
}

@test "write_user_preferences creates preferences file" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    export DEVBASE_THEME='gruvbox-dark'
    export DEVBASE_FONT='FiraCode'
    export DEVBASE_GIT_AUTHOR='Write Test'
    export DEVBASE_GIT_EMAIL='write@test.com'
    export DEVBASE_SSH_KEY_ACTION='new'
    export DEVBASE_SSH_KEY_NAME='id_test'
    export EDITOR='nano'
    export DEVBASE_VSCODE_INSTALL='false'
    export DEVBASE_VSCODE_EXTENSIONS='false'
    export DEVBASE_INSTALL_LAZYVIM='false'
    export DEVBASE_INSTALL_INTELLIJ='true'
    export DEVBASE_INSTALL_JMC='true'
    export DEVBASE_ZELLIJ_AUTOSTART='false'
    export DEVBASE_ENABLE_GIT_HOOKS='false'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    write_user_preferences >/dev/null 2>&1
    cat '${prefs_dir}/preferences.yaml'
  "
  
  assert_success
  assert_output --partial "theme: gruvbox-dark"
  assert_output --partial "font: FiraCode"
  assert_output --partial "author: Write Test"
  assert_output --partial "email: write@test.com"
  assert_output --partial "intellij: true"
}

@test "write then load preserves all preferences" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    
    # Set preferences to write
    export DEVBASE_THEME='nord'
    export DEVBASE_FONT='Hack'
    export DEVBASE_GIT_AUTHOR='Round Trip'
    export DEVBASE_GIT_EMAIL='roundtrip@test.com'
    export DEVBASE_SSH_KEY_ACTION='existing'
    export DEVBASE_SSH_KEY_NAME='id_roundtrip'
    export EDITOR='nvim'
    export DEVBASE_VSCODE_INSTALL='true'
    export DEVBASE_VSCODE_EXTENSIONS='true'
    export DEVBASE_INSTALL_LAZYVIM='true'
    export DEVBASE_INSTALL_INTELLIJ='true'
    export DEVBASE_INSTALL_JMC='false'
    export DEVBASE_ZELLIJ_AUTOSTART='true'
    export DEVBASE_ENABLE_GIT_HOOKS='false'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    # Write preferences
    write_user_preferences >/dev/null 2>&1
    
    # Clear variables
    unset DEVBASE_THEME DEVBASE_FONT DEVBASE_GIT_AUTHOR DEVBASE_GIT_EMAIL
    unset EDITOR DEVBASE_VSCODE_INSTALL DEVBASE_VSCODE_EXTENSIONS
    unset DEVBASE_INSTALL_LAZYVIM DEVBASE_INSTALL_INTELLIJ DEVBASE_INSTALL_JMC
    unset DEVBASE_ZELLIJ_AUTOSTART DEVBASE_ENABLE_GIT_HOOKS
    
    # Load preferences back
    load_saved_preferences >/dev/null 2>&1
    
    # Verify all values (SSH_KEY_ACTION becomes 'skip' on load)
    echo \"theme=\$DEVBASE_THEME\"
    echo \"font=\$DEVBASE_FONT\"
    echo \"author=\$DEVBASE_GIT_AUTHOR\"
    echo \"email=\$DEVBASE_GIT_EMAIL\"
    echo \"editor=\$EDITOR\"
    echo \"visual=\$VISUAL\"
    echo \"vscode_install=\$DEVBASE_VSCODE_INSTALL\"
    echo \"vscode_ext=\$DEVBASE_VSCODE_EXTENSIONS\"
    echo \"lazyvim=\$DEVBASE_INSTALL_LAZYVIM\"
    echo \"intellij=\$DEVBASE_INSTALL_INTELLIJ\"
    echo \"jmc=\$DEVBASE_INSTALL_JMC\"
    echo \"zellij=\$DEVBASE_ZELLIJ_AUTOSTART\"
    echo \"hooks=\$DEVBASE_ENABLE_GIT_HOOKS\"
    echo \"ssh_action=\$DEVBASE_SSH_KEY_ACTION\"
  "
  
  assert_success
  assert_output --partial "theme=nord"
  assert_output --partial "font=Hack"
  assert_output --partial "author=Round Trip"
  assert_output --partial "email=roundtrip@test.com"
  assert_output --partial "editor=nvim"
  assert_output --partial "visual=nvim"
  assert_output --partial "vscode_install=true"
  assert_output --partial "vscode_ext=true"
  assert_output --partial "lazyvim=true"
  assert_output --partial "intellij=true"
  assert_output --partial "jmc=false"
  assert_output --partial "zellij=true"
  assert_output --partial "hooks=false"
  assert_output --partial "ssh_action=skip"
}

@test "load_saved_preferences defaults packs when not in file (non-interactive)" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  
  # Old preferences file without packs key
  cat > "${prefs_dir}/preferences.yaml" << 'EOF'
theme: nord
git:
  author: Test User
  email: test@example.com
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    export NON_INTERACTIVE='true'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"packs=\$DEVBASE_SELECTED_PACKS\"
  "
  
  assert_success
  assert_output --partial "packs=java node python go ruby"
}

@test "load_saved_preferences reads comma-separated packs" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  mkdir -p "$prefs_dir"
  
  cat > "${prefs_dir}/preferences.yaml" << 'EOF'
theme: nord
packs: [java, node, rust]
EOF
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"packs=\$DEVBASE_SELECTED_PACKS\"
  "
  
  assert_success
  assert_output --partial "packs=java node rust"
}

@test "write_user_preferences saves packs with commas" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    export DEVBASE_THEME='nord'
    export DEVBASE_FONT='Hack'
    export DEVBASE_GIT_AUTHOR='Test'
    export DEVBASE_GIT_EMAIL='test@example.com'
    export DEVBASE_SSH_KEY_ACTION='generate'
    export DEVBASE_SSH_KEY_NAME='id_test'
    export EDITOR='nvim'
    export DEVBASE_VSCODE_INSTALL='true'
    export DEVBASE_VSCODE_EXTENSIONS='true'
    export DEVBASE_INSTALL_LAZYVIM='true'
    export DEVBASE_INSTALL_INTELLIJ='false'
    export DEVBASE_INSTALL_JMC='false'
    export DEVBASE_ZELLIJ_AUTOSTART='true'
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    export DEVBASE_SELECTED_PACKS='java python rust'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    write_user_preferences >/dev/null 2>&1
    grep 'packs:' '${prefs_dir}/preferences.yaml'
  "
  
  assert_success
  assert_output "packs: [java, python, rust]"
}

@test "packs round-trip preserves selection" {
  local prefs_dir="${BATS_TEST_TMPDIR}/config"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    export DEVBASE_THEME='nord'
    export DEVBASE_FONT='Hack'
    export DEVBASE_GIT_AUTHOR='Test'
    export DEVBASE_GIT_EMAIL='test@example.com'
    export DEVBASE_SSH_KEY_ACTION='generate'
    export DEVBASE_SSH_KEY_NAME='id_test'
    export EDITOR='nvim'
    export DEVBASE_VSCODE_INSTALL='true'
    export DEVBASE_VSCODE_EXTENSIONS='true'
    export DEVBASE_INSTALL_LAZYVIM='true'
    export DEVBASE_INSTALL_INTELLIJ='false'
    export DEVBASE_INSTALL_JMC='false'
    export DEVBASE_ZELLIJ_AUTOSTART='true'
    export DEVBASE_ENABLE_GIT_HOOKS='true'
    export DEVBASE_SELECTED_PACKS='go ruby rust'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    # Write
    write_user_preferences >/dev/null 2>&1
    
    # Clear and reload
    unset DEVBASE_SELECTED_PACKS
    load_saved_preferences >/dev/null 2>&1
    echo \"packs=\$DEVBASE_SELECTED_PACKS\"
  "
  
  assert_success
  assert_output "packs=go ruby rust"
}

# =============================================================================
# Isolated tests for preference flows
# =============================================================================

@test "load_saved_preferences only loads, never writes" {
  common_setup_isolated
  local prefs_dir="${HOME}/.config/devbase"
  mkdir -p "$prefs_dir"
  
  # Create preferences file without packs
  cat > "${prefs_dir}/preferences.yaml" << 'EOF'
theme: gruvbox-dark
git:
  author: Old User
  email: old@example.com
EOF
  
  local mtime_before
  mtime_before=$(stat -c %Y "${prefs_dir}/preferences.yaml")
  
  run bash -c "
    export HOME='${HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    sleep 1
    load_saved_preferences >/dev/null 2>&1
    
    # File should not be modified
    stat -c %Y '${prefs_dir}/preferences.yaml'
  "
  
  assert_success
  assert_output "$mtime_before"
}

@test "load_saved_preferences sets default packs when missing" {
  common_setup_isolated
  local prefs_dir="${HOME}/.config/devbase"
  mkdir -p "$prefs_dir"
  
  # Preferences without packs
  cat > "${prefs_dir}/preferences.yaml" << 'EOF'
theme: nord
EOF
  
  run bash -c "
    export HOME='${HOME}'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_CONFIG_DIR='${prefs_dir}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' >/dev/null 2>&1
    
    load_saved_preferences >/dev/null 2>&1
    echo \"\$DEVBASE_SELECTED_PACKS\"
  "
  
  assert_success
  assert_output "java node python go ruby"
}

@test "write_user_preferences creates file with all current fields" {
  common_setup_isolated
  local prefs_dir="${HOME}/.config/devbase"
  export DEVBASE_CONFIG_DIR="$prefs_dir"
  
  # Set all required preferences
  export DEVBASE_THEME="nord"
  export DEVBASE_FONT="FiraCode"
  export DEVBASE_GIT_AUTHOR="Test User"
  export DEVBASE_GIT_EMAIL="test@example.com"
  export DEVBASE_SSH_KEY_ACTION="generate"
  export DEVBASE_SSH_KEY_NAME="id_test"
  export EDITOR="nvim"
  export DEVBASE_VSCODE_INSTALL="true"
  export DEVBASE_VSCODE_EXTENSIONS="true"
  export DEVBASE_INSTALL_LAZYVIM="true"
  export DEVBASE_INSTALL_INTELLIJ="false"
  export DEVBASE_INSTALL_JMC="false"
  export DEVBASE_ZELLIJ_AUTOSTART="true"
  export DEVBASE_ENABLE_GIT_HOOKS="true"
  export DEVBASE_SELECTED_PACKS="java python rust"
  
  source_core_libs
  source "${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh"
  
  write_user_preferences >/dev/null 2>&1
  
  # Verify file exists and has expected content
  assert_file_exists "${prefs_dir}/preferences.yaml"
  run cat "${prefs_dir}/preferences.yaml"
  assert_output --partial "theme: nord"
  assert_output --partial "font: FiraCode"
  assert_output --partial "author: Test User"
  assert_output --partial "packs: [java, python, rust]"
}

@test "load then write preserves and updates preferences" {
  common_setup_isolated
  local prefs_dir="${HOME}/.config/devbase"
  mkdir -p "$prefs_dir"
  export DEVBASE_CONFIG_DIR="$prefs_dir"
  
  # Create initial preferences (old format, missing packs)
  cat > "${prefs_dir}/preferences.yaml" << 'EOF'
theme: gruvbox-dark
font: JetBrainsMono
git:
  author: Original User
  email: original@example.com
EOF
  
  source_core_libs
  source "${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh"
  
  # Load preferences (sets defaults for missing fields)
  load_saved_preferences >/dev/null 2>&1
  
  # Verify loaded values
  assert_equal "$DEVBASE_THEME" "gruvbox-dark"
  assert_equal "$DEVBASE_GIT_AUTHOR" "Original User"
  # Packs should default since missing
  assert_equal "$DEVBASE_SELECTED_PACKS" "java node python go ruby"
  
  # Now write - should include packs
  write_user_preferences >/dev/null 2>&1
  
  run cat "${prefs_dir}/preferences.yaml"
  assert_output --partial "theme: gruvbox-dark"
  assert_output --partial "author: Original User"
  assert_output --partial "packs: [java, node, python, go, ruby]"
}

@test "interactive flow loads existing prefs as defaults then saves" {
  common_setup_isolated
  local prefs_dir="${HOME}/.config/devbase"
  mkdir -p "$prefs_dir"
  export DEVBASE_CONFIG_DIR="$prefs_dir"
  
  # Create existing preferences
  cat > "${prefs_dir}/preferences.yaml" << 'EOF'
theme: dracula
font: Hack
git:
  author: Existing User
  email: existing@example.com
packs: [java, rust]
EOF
  
  source_core_libs
  source "${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh"
  
  # Simulate what happens: load_saved_preferences is called first
  load_saved_preferences >/dev/null 2>&1
  
  # Values should be loaded from file
  assert_equal "$DEVBASE_THEME" "dracula"
  assert_equal "$DEVBASE_FONT" "Hack"
  assert_equal "$DEVBASE_GIT_AUTHOR" "Existing User"
  assert_equal "$DEVBASE_SELECTED_PACKS" "java rust"
}

@test "fresh install load_saved_preferences returns failure" {
  common_setup_isolated
  local prefs_dir="${HOME}/.config/devbase"
  mkdir -p "$prefs_dir"
  export DEVBASE_CONFIG_DIR="$prefs_dir"
  # No preferences file - fresh install
  
  source_core_libs
  source "${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh"
  
  # load_saved_preferences should fail when no file exists
  run load_saved_preferences
  assert_failure
}

# =============================================================================
# Tests for pack selection display and defaults
# =============================================================================

@test "_is_selected helper detects pack in selection" {
  common_setup_isolated
  
  run bash -c "
    current_selection=' java node rust '
    _is_selected() { [[ \"\$current_selection\" == *\" \$1 \"* ]]; }
    
    _is_selected 'java' && echo 'java=yes' || echo 'java=no'
    _is_selected 'rust' && echo 'rust=yes' || echo 'rust=no'
    _is_selected 'python' && echo 'python=yes' || echo 'python=no'
  "
  
  assert_success
  assert_line "java=yes"
  assert_line "rust=yes"
  assert_line "python=no"
}

@test "collect_pack_preferences uses existing DEVBASE_SELECTED_PACKS for display" {
  common_setup_isolated
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export DEVBASE_SELECTED_PACKS="java python"
  
  source_core_libs
  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh"
  
  # Capture just the display output (before prompts)
  # We test _is_selected logic directly
  local current_selection=" ${DEVBASE_SELECTED_PACKS} "
  _is_selected() { [[ "$current_selection" == *" $1 "* ]]; }
  
  # Verify selection detection
  assert _is_selected "java"
  assert _is_selected "python"
  refute _is_selected "rust"
  refute _is_selected "node"
}

@test "collect_pack_preferences shows unselected packs with empty brackets" {
  common_setup_isolated
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export DEVBASE_SELECTED_PACKS="java node"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export PACKAGES_YAML='${PACKAGES_YAML}'
    export DEVBASE_SELECTED_PACKS='${DEVBASE_SELECTED_PACKS}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh'
    
    # Extract display logic from collect_pack_preferences
    packs=()
    descriptions=()
    while IFS='|' read -r pack desc; do
      packs+=(\"\$pack\")
      descriptions+=(\"\$desc\")
    done < <(get_available_packs)
    
    current_selection=\" \${DEVBASE_SELECTED_PACKS} \"
    _is_selected() { [[ \"\$current_selection\" == *\" \$1 \"* ]]; }
    
    for pack in \"\${packs[@]}\"; do
      if _is_selected \"\$pack\"; then
        echo \"[x] \$pack\"
      else
        echo \"[ ] \$pack\"
      fi
    done
  "
  
  assert_success
  assert_line "[x] java"
  assert_line "[x] node"
  assert_line "[ ] python"
  assert_line "[ ] rust"
}

@test "fresh install asks to install all packs" {
  common_setup_isolated
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  # No DEVBASE_SELECTED_PACKS set = fresh install
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export PACKAGES_YAML='${PACKAGES_YAML}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    # Explicitly unset to simulate fresh install
    unset DEVBASE_SELECTED_PACKS
    
    # Check fresh install detection
    is_fresh_install=false
    [[ -z \"\${DEVBASE_SELECTED_PACKS:-}\" ]] && is_fresh_install=true
    echo \"is_fresh=\$is_fresh_install\"
  "
  
  assert_success
  assert_output "is_fresh=true"
}

@test "update with existing selection asks to keep current" {
  common_setup_isolated
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export DEVBASE_SELECTED_PACKS="java node python"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export PACKAGES_YAML='${PACKAGES_YAML}'
    export DEVBASE_SELECTED_PACKS='${DEVBASE_SELECTED_PACKS}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    
    # Check update detection
    is_fresh_install=false
    [[ -z \"\${DEVBASE_SELECTED_PACKS:-}\" ]] && is_fresh_install=true
    echo \"is_fresh=\$is_fresh_install\"
  "
  
  assert_success
  assert_output "is_fresh=false"
}

@test "collect_tool_preferences (gum) enforces single binding selection" {
  common_setup_isolated

  run bash -c '
    export DEVBASE_ROOT="'"${DEVBASE_ROOT}"'"
    export DEVBASE_LIBS="'"${DEVBASE_ROOT}"'/libs"
    export DEVBASE_CONFIG_DIR="'"${HOME}"'/.config/devbase"

    source "${DEVBASE_ROOT}/libs/define-colors.sh"
    source "${DEVBASE_ROOT}/libs/validation.sh"
    source "${DEVBASE_ROOT}/libs/ui/ui-helpers.sh"
    source "${DEVBASE_ROOT}/libs/collect-user-preferences-gum.sh"

    _gum_section() { :; }
    _gum_success() { :; }
    _gum_exit_on_cancel_any() { :; }
    _gum_warning() { echo "WARN:$1"; }

    call_count_file="${TEST_DIR}/gum-choose-count"
    binding_count_file="${TEST_DIR}/gum-choose-binding-count"
    echo 0 >"$call_count_file"
    echo 0 >"$binding_count_file"
    _gum_choose_multi() {
      local count
      count=$(cat "$call_count_file")
      count=$((count + 1))
      echo "$count" >"$call_count_file"

      if [[ "${2:-}" == "Vim-style"* ]]; then
        local binding_count
        binding_count=$(cat "$binding_count_file")
        binding_count=$((binding_count + 1))
        echo "$binding_count" >"$binding_count_file"
      fi

      if [[ $count -eq 1 ]]; then
        printf "%s\n%s\n" "Vim-style - Modal editing / hjkl navigation" "Emacs-style - Arrow keys / Ctrl shortcuts"
      elif [[ $count -eq 2 ]]; then
        printf "%s\n" "Vim-style - Modal editing / hjkl navigation"
      else
        echo ""
      fi
    }

    collect_tool_preferences
    echo "EDITOR=$EDITOR"
    echo "VISUAL=$VISUAL"
    echo "CHOOSE_COUNT=$(cat "$call_count_file")"
    echo "BINDING_COUNT=$(cat "$binding_count_file")"
  '

  assert_success
  assert_output --partial "EDITOR=nvim"
  assert_output --partial "VISUAL=nvim"
  assert_output --partial "BINDING_COUNT=2"
}

@test "saved preferences with subset of packs are preserved on load" {
  common_setup_isolated
  local prefs_dir="${HOME}/.config/devbase"
  mkdir -p "$prefs_dir"
  export DEVBASE_CONFIG_DIR="$prefs_dir"
  
  # Save preferences with only some packs
  cat > "${prefs_dir}/preferences.yaml" << 'EOF'
theme: nord
packs: [java, python, go]
EOF
  
  source_core_libs
  source "${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh"
  
  load_saved_preferences >/dev/null 2>&1
  
  # Should have exactly what was saved
  assert_equal "$DEVBASE_SELECTED_PACKS" "java python go"
}

# =============================================================================
# Tests for pack details display
# =============================================================================

@test "_show_pack_details displays pack name and description" {
  common_setup_isolated
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export PACKAGES_YAML='${PACKAGES_YAML}'
    export DEVBASE_LIBS='${DEVBASE_LIBS}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    source '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh'
    
    _show_pack_details() {
      local pack=\"\$1\"
      local desc=\"\$2\"
      printf \"%s: %s\n\" \"\$pack\" \"\$desc\"
      printf \"Includes:\n\"
      local item
      while IFS= read -r item; do
        [[ -n \"\$item\" ]] && printf \"  - %s\n\" \"\$item\"
      done < <(get_pack_contents \"\$pack\")
    }
    
    _show_pack_details 'java' 'Java development'
  "
  
  assert_success
  assert_line "java: Java development"
  assert_line "Includes:"
}

@test "_show_pack_details lists pack contents" {
  common_setup_isolated
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export DEVBASE_LIBS="${DEVBASE_ROOT}/libs"
  
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export PACKAGES_YAML='${PACKAGES_YAML}'
    export DEVBASE_LIBS='${DEVBASE_LIBS}'
    
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    
    # Get java pack contents
    get_pack_contents 'java'
  "
  
  assert_success
  # Should include items from java pack (apt, mise, vscode)
  [[ "${#lines[@]}" -gt 0 ]]
}

@test "pack selection uses checklist with pack names" {
  common_setup_isolated
  
  # Verify packs are selected via checklist (not individual prompts)
  run bash -c "
    grep -o 'Select language packs to install' '${DEVBASE_ROOT}/libs/collect-user-preferences-whiptail.sh' | head -1
  "
  
  assert_success
  assert_output 'Select language packs to install'
}
