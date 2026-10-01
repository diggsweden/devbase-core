#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218,SC2329

bats_require_minimum_version 1.13.0
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  source_core_libs
  # shellcheck disable=SC2153 # DEVBASE_ROOT is set by common_setup_isolated
  source "${DEVBASE_ROOT}/libs/utils.sh"
  source "${DEVBASE_ROOT}/libs/process-templates.sh"
  export DEVBASE_FILES="${DEVBASE_ROOT}/devbase_files"
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export DEVBASE_BACKUP_DIR="${XDG_DATA_HOME}/devbase/backup"
  export _DEVBASE_TEMP="${TEST_DIR}/work"
  export _DEVBASE_CUSTOM_TEMPLATES=''
  export DEVBASE_PROXY_HOST='' DEVBASE_PROXY_PORT='' DEVBASE_REGISTRY_URL=''
  export DEVBASE_REGISTRY_HOST='' DEVBASE_REGISTRY_PORT=''
  export DEVBASE_PYPI_REGISTRY='' DEVBASE_NPM_REGISTRY='' DEVBASE_CYPRESS_REGISTRY=''
  export DEVBASE_TESTCONTAINERS_PREFIX='' DEVBASE_THEME='test'
  mkdir -p "$DEVBASE_DOT/.config/starship" "$DEVBASE_DOT/.config/fish/functions" \
    "$DEVBASE_DOT/.config/nvim/lua/plugins" "$_DEVBASE_TEMP"
  echo '# Initial prompt' >"$DEVBASE_DOT/.config/starship/starship.toml.template"
  echo '# Managed v1' >"$DEVBASE_DOT/.config/fish/functions/__devbase_configure_proxy_curl.fish"
  echo '-- Starter only' >"$DEVBASE_DOT/.config/nvim/lua/plugins/treesitter.lua"
  apply_theme() { :; }
  is_wsl() { return 1; }
  install_wsl_terminal_themes() { :; }
}

teardown() {
  common_teardown
}

reinstall_configs() {
  export _DEVBASE_TEMP="$(mktemp -d "${TEST_DIR}/run.XXXXXX")"
  process_and_copy_dotfiles
}

@test "configuration lifecycle preserves personal files and updates managed defaults" {
  mkdir -p "$XDG_CONFIG_HOME/mytool" "$XDG_CONFIG_HOME/nvim/after"
  echo 'private template' >"$XDG_CONFIG_HOME/mytool/settings.template"
  echo '-- Personal plugin' >"$XDG_CONFIG_HOME/nvim/after/personal.lua"
  run reinstall_configs
  assert_success
  assert_equal "$(cat "$XDG_CONFIG_HOME/starship/starship.toml")" '# Initial prompt'

  echo '# Personal prompt' >"$XDG_CONFIG_HOME/starship/starship.toml"
  echo 'testcontainers.reuse.enable=false' >"$HOME/.testcontainers.properties"
  echo '# New upstream prompt' >"$DEVBASE_DOT/.config/starship/starship.toml.template"
  echo '# Managed v2' >"$DEVBASE_DOT/.config/fish/functions/__devbase_configure_proxy_curl.fish"
  run reinstall_configs
  assert_success
  run reinstall_configs
  assert_success
  assert_equal "$(cat "$XDG_CONFIG_HOME/starship/starship.toml")" '# Personal prompt'
  assert_equal "$(cat "$HOME/.testcontainers.properties")" 'testcontainers.reuse.enable=false'
  assert_equal "$(cat "$XDG_CONFIG_HOME/mytool/settings.template")" 'private template'
  assert_equal "$(cat "$XDG_CONFIG_HOME/nvim/after/personal.lua")" '-- Personal plugin'
  assert_file_not_exists "$XDG_CONFIG_HOME/nvim/lua/plugins/treesitter.lua"
  assert_equal "$(cat "$XDG_CONFIG_HOME/fish/functions/__devbase_configure_proxy_curl.fish")" '# Managed v2'
}

@test "template overlays reach their real destinations and leave organization inputs intact" {
  export _DEVBASE_CUSTOM_TEMPLATES="$TEST_DIR/custom"
  mkdir -p "$_DEVBASE_CUSTOM_TEMPLATES"
  echo '# Organization prompt' >"$_DEVBASE_CUSTOM_TEMPLATES/starship.toml.template"
  echo '# Organization helper' >"$_DEVBASE_CUSTOM_TEMPLATES/__devbase_configure_proxy_curl.fish"
  echo 'registry=https://registry.example.com' >"$_DEVBASE_CUSTOM_TEMPLATES/npmrc.template"
  echo 'testcontainers.reuse.enable=false' >"$_DEVBASE_CUSTOM_TEMPLATES/.testcontainers.properties.template"
  run reinstall_configs
  assert_success
  refute_output --partial 'Unknown custom file type'
  assert_equal "$(cat "$XDG_CONFIG_HOME/starship/starship.toml")" '# Organization prompt'
  assert_equal "$(cat "$XDG_CONFIG_HOME/fish/functions/__devbase_configure_proxy_curl.fish")" '# Organization helper'
  assert_file_not_exists "$HOME/.starship.toml"
  assert_equal "$(cat "$HOME/.npmrc")" 'registry=https://registry.example.com'
  assert_equal "$(cat "$HOME/.testcontainers.properties")" 'testcontainers.reuse.enable=false'
  assert_file_exists "$_DEVBASE_CUSTOM_TEMPLATES/starship.toml.template"
  assert_file_exists "$_DEVBASE_CUSTOM_TEMPLATES/npmrc.template"

  echo '//registry.example.com/:_authToken=personal' >"$HOME/.npmrc"
  run reinstall_configs
  assert_success
  assert_equal "$(cat "$HOME/.npmrc")" '//registry.example.com/:_authToken=personal'
}

@test "ambiguous organization template names fail without replacing either candidate" {
  mkdir -p "$TEST_DIR/stage/a" "$TEST_DIR/stage/b" "$TEST_DIR/custom"
  echo 'first' >"$TEST_DIR/stage/a/config.template"
  echo 'second' >"$TEST_DIR/stage/b/config.template"
  echo 'custom' >"$TEST_DIR/custom/config.template"
  export _DEVBASE_CUSTOM_TEMPLATES="$TEST_DIR/custom"
  run copy_custom_templates_to_temp "$TEST_DIR/stage"
  assert_failure
  assert_output --partial 'Ambiguous'
  assert_equal "$(cat "$TEST_DIR/stage/a/config.template")" 'first'
  assert_equal "$(cat "$TEST_DIR/stage/b/config.template")" 'second'
}

@test "personal defaults preserve empty files and dangling symlinks" {
  mkdir -p "$XDG_CONFIG_HOME/starship"
  touch "$XDG_CONFIG_HOME/starship/starship.toml"
  ln -s "$TEST_DIR/missing.properties" "$HOME/.testcontainers.properties"
  run reinstall_configs
  assert_success
  assert [ ! -s "$XDG_CONFIG_HOME/starship/starship.toml" ]
  assert_symlink_to "$TEST_DIR/missing.properties" "$HOME/.testcontainers.properties"
  assert_file_not_exists "$TEST_DIR/missing.properties"
}

@test "bashrc append preserves existing content and permissions and adds a literal block once" {
  printf '# Personal configuration without a final newline' >"$HOME/.bashrc"
  chmod 640 "$HOME/.bashrc"
  cp "$HOME/.bashrc" "$TEST_DIR/before"
  printf 'export ORG_PATH="$HOME/tools:$PATH"\nalias org-ls="ls *"' >"$TEST_DIR/bashrc.append"

  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_success
  assert_files_equal "$TEST_DIR/before" "$DEVBASE_BACKUP_DIR/append/bashrc"
  assert_equal "$(stat -c %a "$HOME/.bashrc")" 640
  cat "$TEST_DIR/before" >"$TEST_DIR/expected"
  printf '\n' >>"$TEST_DIR/expected"
  cat "$TEST_DIR/bashrc.append" >>"$TEST_DIR/expected"
  printf '\n' >>"$TEST_DIR/expected"
  assert_files_equal "$TEST_DIR/expected" "$HOME/.bashrc"

  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_success
  assert_files_equal "$TEST_DIR/expected" "$HOME/.bashrc"
  assert_file_not_exists "$DEVBASE_BACKUP_DIR/append/bashrc.~1~"
}

_setup_bashrc_with_fish_handoff() {
  source "$DEVBASE_LIBS/configure-shell.sh"
  mkdir -p "$TEST_DIR/bin"
  cat >"$TEST_DIR/bin/fish" <<'EOF'
#!/bin/sh
printf 'organization setting: %s\n' "${DEVBASE_TEST_ORG_SETTING:-unset}"
EOF
  chmod +x "$TEST_DIR/bin/fish"
  export PATH="$TEST_DIR/bin:$PATH" DEVBASE_SHELLS_FILE="$TEST_DIR/shells"
  printf '%s\n' "$TEST_DIR/bin/fish" >"$DEVBASE_SHELLS_FILE"
  unset DEVBASE_TEST_ORG_SETTING BASH_ENV ENV
  echo '# Personal shell configuration' >"$HOME/.bashrc"
  configure_fish_interactive
  echo 'export DEVBASE_TEST_ORG_SETTING="present"' >"$TEST_DIR/bashrc.append"
}

@test "bashrc append runs before an existing Fish handoff on reinstall" {
  _setup_bashrc_with_fish_handoff
  cp "$HOME/.bashrc" "$TEST_DIR/before"
  process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  configure_fish_interactive

  run --separate-stderr bash --noprofile --rcfile "$HOME/.bashrc" -i -c true
  assert_success
  assert_line 'organization setting: present'
  assert_files_equal "$TEST_DIR/before" "$DEVBASE_BACKUP_DIR/append/bashrc"
  cp "$HOME/.bashrc" "$TEST_DIR/after"
  process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_files_equal "$TEST_DIR/after" "$HOME/.bashrc"
}

@test "bashrc append does not count an unreachable block after the Fish handoff" {
  _setup_bashrc_with_fish_handoff
  cat "$TEST_DIR/bashrc.append" >>"$HOME/.bashrc"
  process_append_file "$TEST_DIR/bashrc.append" bashrc.append

  run --separate-stderr bash --noprofile --rcfile "$HOME/.bashrc" -i -c true
  assert_success
  assert_line 'organization setting: present'
  cp "$HOME/.bashrc" "$TEST_DIR/after"
  process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_files_equal "$TEST_DIR/after" "$HOME/.bashrc"
}

@test "bashrc append initializes a missing file and ignores an empty block" {
  touch "$TEST_DIR/bashrc.append"
  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_success
  assert_file_not_exists "$HOME/.bashrc"
  echo 'export ORG_SETTING=enabled' >"$TEST_DIR/bashrc.append"
  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_success
  assert_files_equal "$TEST_DIR/bashrc.append" "$HOME/.bashrc"
  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_success
  assert_files_equal "$TEST_DIR/bashrc.append" "$HOME/.bashrc"
}

@test "bashrc append preserves links and rejects unsupported append destinations" {
  echo 'export ORG_SETTING=enabled' >"$TEST_DIR/bashrc.append"
  ln -s "$TEST_DIR/personal-bashrc" "$HOME/.bashrc"
  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_success
  assert_output --partial 'Preserving linked .bashrc'
  assert_file_not_exists "$TEST_DIR/personal-bashrc"
  echo '# Personal shell config' >"$TEST_DIR/personal-bashrc"
  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_success
  assert_equal "$(cat "$TEST_DIR/personal-bashrc")" '# Personal shell config'
  run process_append_file "$TEST_DIR/bashrc.append" npmrc.append
  assert_success
  assert_output --partial 'Unsupported append file'
  assert_file_not_exists "$HOME/.npmrc"
}

@test "bashrc append leaves the original intact on backup and publication failures" {
  echo '# Personal shell config' >"$HOME/.bashrc"
  cp "$HOME/.bashrc" "$TEST_DIR/before"
  echo 'export ORG_SETTING=enabled' >"$TEST_DIR/bashrc.append"
  mkdir -p "$DEVBASE_BACKUP_DIR"
  echo 'blocking file' >"$DEVBASE_BACKUP_DIR/append"
  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_failure
  assert_files_equal "$TEST_DIR/before" "$HOME/.bashrc"

  rm "$DEVBASE_BACKUP_DIR/append"
  mv() { return 1; }
  run process_append_file "$TEST_DIR/bashrc.append" bashrc.append
  assert_failure
  assert_files_equal "$TEST_DIR/before" "$HOME/.bashrc"
  assert_files_equal "$TEST_DIR/before" "$DEVBASE_BACKUP_DIR/append/bashrc"
}

@test "Maven without applicable configuration does not create settings" {
  run process_maven_templates_yaml
  assert_success
  assert_file_not_exists "$HOME/.m2/settings.xml"
}

@test "Maven personal credentials comments and symlinks survive configured defaults" {
  mkdir -p "$HOME/.m2"
  echo '<settings><!-- personal --><servers><server><password>secret</password></server></servers></settings>' >"$TEST_DIR/settings.xml"
  cp "$TEST_DIR/settings.xml" "$HOME/.m2/settings.xml"
  export DEVBASE_PROXY_HOST=proxy.example.com DEVBASE_PROXY_PORT=8080
  run process_maven_templates_yaml
  assert_success
  assert_files_equal "$TEST_DIR/settings.xml" "$HOME/.m2/settings.xml"
  refute_output --partial 'secret'
  rm "$HOME/.m2/settings.xml"
  touch "$HOME/.m2/settings.xml"
  run process_maven_templates_yaml
  assert_success
  assert [ ! -s "$HOME/.m2/settings.xml" ]
  rm "$HOME/.m2/settings.xml"
  ln -s "$TEST_DIR/missing.xml" "$HOME/.m2/settings.xml"
  run process_maven_templates_yaml
  assert_success
  assert_symlink_to "$TEST_DIR/missing.xml" "$HOME/.m2/settings.xml"
  assert_file_not_exists "$TEST_DIR/missing.xml"
}

@test "Maven fresh generation produces valid private settings and preserves later edits" {
  export DEVBASE_PROXY_HOST=proxy.example.com DEVBASE_PROXY_PORT=8080
  run process_maven_templates_yaml
  assert_success
  assert_equal "$(stat -c %a "$HOME/.m2/settings.xml")" '600'
  run yq -p=xml -o=yaml -r '.settings.proxies.proxy[0].host' "$HOME/.m2/settings.xml"
  assert_success
  assert_output 'proxy.example.com'
  echo '<!-- user edit -->' >>"$HOME/.m2/settings.xml"
  cp "$HOME/.m2/settings.xml" "$TEST_DIR/expected.xml"
  export DEVBASE_PROXY_HOST=changed.example.com
  run process_maven_templates_yaml
  assert_success
  assert_files_equal "$TEST_DIR/expected.xml" "$HOME/.m2/settings.xml"
}

@test "Maven failed generation does not publish a partial settings file" {
  export DEVBASE_PROXY_HOST=proxy.example.com DEVBASE_PROXY_PORT=8080
  _process_maven_yaml_to_xml() { printf '<broken' >"$2"; return 1; }
  run process_maven_templates_yaml
  assert_failure
  assert_file_not_exists "$HOME/.m2/settings.xml"
}

@test "rendering and backup failures stop configuration deployment" {
  envsubst_preserve_undefined() { return 1; }
  run reinstall_configs
  assert_failure
  assert_file_not_exists "$XDG_CONFIG_HOME/fish/functions/__devbase_configure_proxy_curl.fish"
  unset -f envsubst_preserve_undefined
  mkdir -p "$TEST_DIR/stage"
  echo 'new' >"$TEST_DIR/stage/.managed"
  echo 'old' >"$HOME/.managed"
  merge_dotfiles_with_backup() { return 1; }
  run install_dotfiles_to_target "$TEST_DIR/stage"
  assert_failure
  assert_equal "$(cat "$HOME/.managed")" old
}

@test "personal Gradle and container settings survive organization templates" {
  export DEVBASE_REGISTRY_URL=https://registry.example.com DEVBASE_REGISTRY_HOST=registry.example.com DEVBASE_REGISTRY_PORT=443
  export _DEVBASE_CUSTOM_TEMPLATES="$TEST_DIR/custom" GRADLE_USER_HOME="$TEST_DIR/gradle"
  mkdir -p "$_DEVBASE_CUSTOM_TEMPLATES" "$GRADLE_USER_HOME" "$XDG_CONFIG_HOME/containers"
  echo '// New org settings' >"$_DEVBASE_CUSTOM_TEMPLATES/init.gradle.template"
  echo '# New org settings' >"$_DEVBASE_CUSTOM_TEMPLATES/registries.conf.template"
  echo '// Personal settings' >"$GRADLE_USER_HOME/init.gradle"
  echo '# Personal settings' >"$XDG_CONFIG_HOME/containers/registries.conf"
  run process_gradle_templates
  assert_success
  run process_container_templates
  assert_success
  assert_equal "$(cat "$GRADLE_USER_HOME/init.gradle")" '// Personal settings'
  assert_equal "$(cat "$XDG_CONFIG_HOME/containers/registries.conf")" '# Personal settings'
}

@test "create-only publication cannot overwrite a destination created during copying" {
  echo 'seed' >"$TEST_DIR/seed"
  cp() { command cp "$@" && printf 'racing user edit\n' >"$TEST_DIR/target"; }
  run install_file_if_missing "$TEST_DIR/seed" "$TEST_DIR/target"
  assert_success
  assert_equal "$(cat "$TEST_DIR/target")" 'racing user edit'
}

@test "create-only copy failure leaves the target absent" {
  echo 'seed' >"$TEST_DIR/seed"
  cp() { return 1; }
  run install_file_if_missing "$TEST_DIR/seed" "$TEST_DIR/target"
  assert_failure
  assert_file_not_exists "$TEST_DIR/target"
}

@test "Starship startup respects an explicit config and the conventional personal path" {
  export EDITOR=nvim VISUAL=nvim DEVBASE_CUSTOM_CERTS='' BAT_THEME=default DEVBASE_ZELLIJ_AUTOSTART=false
  envsubst_preserve_undefined "$DEVBASE_ROOT/dot/.config/fish/conf.d/00-0-environment.fish.template" "$TEST_DIR/environment.fish"
  run --separate-stderr fish --no-config -c '
    set -gx STARSHIP_CONFIG "$argv[2]"
    source "$argv[1]"
    printf "%s\n" "$STARSHIP_CONFIG"
  ' -- "$TEST_DIR/environment.fish" "$TEST_DIR/custom-starship.toml"
  assert_success
  assert_output "$TEST_DIR/custom-starship.toml"

  touch "$XDG_CONFIG_HOME/starship.toml"
  run --separate-stderr fish --no-config -c '
    set -e STARSHIP_CONFIG
    source "$argv[1]"
    printf "%s\n" "$STARSHIP_CONFIG"
  ' -- "$TEST_DIR/environment.fish"
  assert_success
  assert_output "$XDG_CONFIG_HOME/starship.toml"
}

@test "final cleanup preserves an existing linked Neovim repository" {
  mkdir -p "$TEST_DIR/personal-nvim/.git"
  echo 'ref: refs/heads/main' >"$TEST_DIR/personal-nvim/.git/HEAD"
  ln -s "$TEST_DIR/personal-nvim" "$XDG_CONFIG_HOME/nvim"
  export DEVBASE_FILES="$TEST_DIR/no-system-config"
  cleanup_with_dependencies() {
    # install.sh invokes main when sourced; load only cleanup, as other install
    # tests do, so no system installation can run in this regression test.
    source <(sed -n '/^cleanup()/,/^}/p' "$DEVBASE_ROOT/libs/install.sh")
    pkg_cleanup() { :; }
    cleanup
  }
  run cleanup_with_dependencies
  assert_success
  assert_symlink_to "$TEST_DIR/personal-nvim" "$XDG_CONFIG_HOME/nvim"
  assert_equal "$(cat "$TEST_DIR/personal-nvim/.git/HEAD")" 'ref: refs/heads/main'
  assert_dir_not_exists "$TEST_DIR/personal-nvim/.git-nvim-git-old"
}
