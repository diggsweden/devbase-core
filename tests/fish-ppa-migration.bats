#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
# shellcheck disable=SC1090,SC2030,SC2031,SC2329

bats_require_minimum_version 1.13.0
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  source_core_libs
  source "$DEVBASE_ROOT/libs/migrations.sh"
  source "$DEVBASE_ROOT/libs/pkg/pkg-apt.sh"
  export DEVBASE_BACKUP_DIR="$XDG_DATA_HOME/devbase/backup"
  APT_DIR="$TEST_DIR/apt"
  mkdir -p "$APT_DIR/sources.list.d" "$APT_DIR/keyrings"
  # This suite only removes fixture source files; never run real sudo or APT.
  sudo() {
    [[ "$1" == rm && "${*: -1}" == "$APT_DIR/"* ]] || return 99
    "$@"
  }
}

teardown() {
  common_teardown
}

@test "Fish PPA migration backs up deb822 sources, keeps keys and is idempotent" {
  local file="$APT_DIR/sources.list.d/fish-shell-ubuntu-release-4-resolute.sources"
  cat >"$file" <<'EOF'
Types: deb deb-src
URIs: https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu/
Suites: resolute
Components: main
Signed-By: /etc/apt/keyrings/fish.gpg
EOF
  cp "$file" "$TEST_DIR/original"
  printf 'key fixture\n' >"$APT_DIR/keyrings/fish.gpg"
  printf 'Types: deb\nURIs: https://archive.ubuntu.com/ubuntu\nSuites: resolute\nComponents: main' >"$APT_DIR/sources.list.d/ubuntu.sources"
  cp "$APT_DIR/sources.list.d/ubuntu.sources" "$TEST_DIR/ubuntu"
  run migrate_fish_ppa "$APT_DIR"
  assert_success
  assert_file_not_exists "$file"
  assert_files_equal "$TEST_DIR/original" "$DEVBASE_BACKUP_DIR/apt/sources.list.d/$(basename "$file")"
  assert_files_equal "$TEST_DIR/ubuntu" "$APT_DIR/sources.list.d/ubuntu.sources"
  assert_equal "$(cat "$APT_DIR/keyrings/fish.gpg")" 'key fixture'
  run migrate_fish_ppa "$APT_DIR"
  assert_success
  assert_equal "$(find "$DEVBASE_BACKUP_DIR/apt" -type f | wc -l)" 1
}

@test "Fish PPA migration handles legacy list URLs and source entries" {
  local file="$APT_DIR/sources.list.d/fish.list"
  printf '# Old Fish source\ndeb [arch=amd64] http://ppa.launchpad.net/fish-shell/release-4/ubuntu resolute main\ndeb-src https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu/ resolute main\n' >"$file"
  cp "$file" "$TEST_DIR/original"
  run migrate_fish_ppa "$APT_DIR"
  assert_success
  assert_file_not_exists "$file"
  assert_files_equal "$TEST_DIR/original" "$DEVBASE_BACKUP_DIR/apt/sources.list.d/fish.list"
}

@test "Fish PPA migration ignores comments, signing keys and similar repository URLs" {
  local file="$APT_DIR/sources.list.d/other.list"
  cat >"$file" <<'EOF'
# deb https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu resolute main
deb https://ppa.launchpadcontent.net/fish-shell/release-40/ubuntu resolute main
deb https://ppa.launchpadcontent.net.example/fish-shell/release-4/ubuntu resolute main
deb https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu/other resolute main
EOF
  cp "$file" "$TEST_DIR/original"
  printf 'Types: deb\nURIs: https://packages.example/ubuntu\nSigned-By: https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu\n' >"$APT_DIR/sources.list.d/other.sources"
  cp "$APT_DIR/sources.list.d/other.sources" "$TEST_DIR/original.sources"
  run migrate_fish_ppa "$APT_DIR"
  assert_success
  assert_files_equal "$TEST_DIR/original" "$file"
  assert_files_equal "$TEST_DIR/original.sources" "$APT_DIR/sources.list.d/other.sources"
  assert_dir_not_exists "$DEVBASE_BACKUP_DIR/apt"
}

@test "Fish PPA migration refuses a shared legacy source file" {
  local file="$APT_DIR/sources.list"
  printf 'deb https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu resolute main\ndeb https://archive.ubuntu.com/ubuntu resolute main\n' >"$file"
  cp "$file" "$TEST_DIR/original"
  run migrate_fish_ppa "$APT_DIR"
  assert_failure
  assert_output --partial 'shared APT source'
  assert_files_equal "$TEST_DIR/original" "$file"
}

@test "Fish PPA migration refuses deb822 sources shared with another URI or stanza" {
  local file="$APT_DIR/sources.list.d/shared.sources"
  for separator in ' ' $'\n\nTypes: deb\nURIs: '; do
    printf 'Types: deb\nURIs: https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu%shttps://archive.ubuntu.com/ubuntu\nSuites: resolute\nComponents: main\n' "$separator" >"$file"
    cp "$file" "$TEST_DIR/original"
    run migrate_fish_ppa "$APT_DIR"
    assert_failure
    assert_output --partial 'shared APT source'
    assert_files_equal "$TEST_DIR/original" "$file"
  done
}

@test "Fish PPA migration does not follow linked source files" {
  printf 'deb https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu resolute main\n' >"$TEST_DIR/personal.list"
  ln -s "$TEST_DIR/personal.list" "$APT_DIR/sources.list.d/fish.list"
  run migrate_fish_ppa "$APT_DIR"
  assert_failure
  assert_symlink_to "$TEST_DIR/personal.list" "$APT_DIR/sources.list.d/fish.list"
  assert_equal "$(cat "$TEST_DIR/personal.list")" 'deb https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu resolute main'
}

@test "Fish PPA migration preserves existing backups" {
  local file="$APT_DIR/sources.list.d/fish.list" backup="$DEVBASE_BACKUP_DIR/apt/sources.list.d/fish.list"
  printf 'deb https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu resolute main\n' >"$file"
  cp "$file" "$TEST_DIR/original"
  mkdir -p "$(dirname "$backup")"
  printf 'earlier backup\n' >"$backup"
  run migrate_fish_ppa "$APT_DIR"
  assert_success
  assert_files_equal "$TEST_DIR/original" "$backup"
  assert_equal "$(cat "$backup.~1~")" 'earlier backup'
}

@test "Fish PPA migration keeps the source if backup copying fails and retries safely" {
  local file="$APT_DIR/sources.list.d/fish.list" backup="$DEVBASE_BACKUP_DIR/apt/sources.list.d/fish.list"
  printf 'deb https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu resolute main\n' >"$file"
  cp "$file" "$TEST_DIR/original"
  cp() { printf 'partial\n' >"${*: -1}"; return 1; }
  run migrate_fish_ppa "$APT_DIR"
  assert_failure
  assert_files_equal "$TEST_DIR/original" "$file"
  assert_file_not_exists "$backup"
  unset -f cp
  run migrate_fish_ppa "$APT_DIR"
  assert_success
  assert_files_equal "$TEST_DIR/original" "$backup"
}

@test "Fish PPA migration refuses linked backups" {
  local file="$APT_DIR/sources.list.d/fish.list" backup="$DEVBASE_BACKUP_DIR/apt/sources.list.d/fish.list"
  printf 'deb https://ppa.launchpadcontent.net/fish-shell/release-4/ubuntu resolute main\n' >"$file"
  mkdir -p "$(dirname "$backup")"
  printf 'personal backup\n' >"$TEST_DIR/personal"
  ln -s "$TEST_DIR/personal" "$backup"
  run migrate_fish_ppa "$APT_DIR"
  assert_failure
  assert_file_exists "$file"
  assert_symlink_to "$TEST_DIR/personal" "$backup"
  assert_equal "$(cat "$TEST_DIR/personal")" 'personal backup'
}

@test "APT update runs the Fish PPA migration before fetching package lists" {
  migrate_fish_ppa() { printf 'migration\n' >>"$TEST_DIR/calls"; }
  _pkg_apt_configure_mirror() { :; }
  run_with_spinner() { printf 'apt\n' >>"$TEST_DIR/calls"; }
  run _pkg_apt_update
  assert_success
  assert_equal "$(cat "$TEST_DIR/calls")" $'migration\napt'
}

@test "APT update stops before fetching package lists if Fish PPA migration fails" {
  migrate_fish_ppa() { return 1; }
  _pkg_apt_configure_mirror() { touch "$TEST_DIR/mirror"; }
  run_with_spinner() { touch "$TEST_DIR/apt"; }
  run _pkg_apt_update
  assert_failure
  assert_file_not_exists "$TEST_DIR/mirror"
  assert_file_not_exists "$TEST_DIR/apt"
}
