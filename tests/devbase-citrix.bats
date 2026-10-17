#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Tests for devbase-citrix fish function

bats_require_minimum_version 1.5.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
  export DEVBASE_CITRIX_FISH="${DEVBASE_ROOT}/dot/.config/fish/functions/devbase-citrix.fish"
}

teardown() {
  common_teardown
}

# Helper to run fish commands with the devbase-citrix function loaded
run_fish_citrix() {
  fish --no-config -c "source '$DEVBASE_CITRIX_FISH'; $*"
}

# Citrix installs on Debian/Ubuntu amd64 only. Tests that stop before any
# package is read can use stand-ins, so they also run on Fedora runners.
_fake_debian_amd64_tools() {
  mkdir -p "$TEST_DIR/fakebin"
  printf '#!/bin/sh\n[ "$1" = --print-architecture ] && echo amd64\n' >"$TEST_DIR/fakebin/dpkg"
  printf '#!/bin/sh\nexit 1\n' >"$TEST_DIR/fakebin/dpkg-deb"
  chmod +x "$TEST_DIR/fakebin/dpkg" "$TEST_DIR/fakebin/dpkg-deb"
  export PATH="$TEST_DIR/fakebin:$PATH"
}

@test "devbase-citrix.fish function file exists" {
  assert_file_exists "$DEVBASE_CITRIX_FISH"
}

@test "devbase-citrix --help shows usage" {
  run run_fish_citrix "devbase-citrix --help"
  
  assert_success
  assert_output --partial "Usage:"
  assert_output --partial "--check"
  assert_output --partial "Citrix Workspace App"
}

@test "devbase-citrix --check shows pinned version" {
  run run_fish_citrix "devbase-citrix --check"
  
  assert_success
  assert_output --partial "Pinned version:"
  assert_output --partial "Packages:"
  assert_output --partial "icaclient_"
  assert_output --partial "_amd64.deb"
}

@test "__citrix_get_version returns version string" {
  run run_fish_citrix "__citrix_get_version"
  
  assert_success
  # Version format: XX.XX.XX.XXX (e.g., 25.08.10.111)
  assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

@test "__citrix_get_static_urls lists both amd64 naming variants" {
  run run_fish_citrix "__citrix_get_static_urls"
  
  assert_success
  # Should have icaclient and ctxusb URLs
  assert_output --partial "icaclient_"
  assert_output --partial "ctxusb_"
  assert_output --partial "downloads.citrix.com"
  assert_output --partial "_amd64.deb"
}

@test "__citrix_get_static_urls includes version in URLs" {
  local citrix_ver
  citrix_ver=$(run_fish_citrix "__citrix_get_version")
  
  run run_fish_citrix "__citrix_get_static_urls"
  
  assert_success
  assert_output --partial "icaclient_${citrix_ver}_amd64.deb"
  assert_output --partial "ctxusb_${citrix_ver}_amd64.deb"
}

@test "devbase-citrix unknown option shows error" {
  run run_fish_citrix "devbase-citrix --invalid"
  
  assert_failure
  assert_output --partial "Unknown option"
}

@test "citrix version file contains renovate comment" {
  run grep -E "^# renovate:" "$DEVBASE_CITRIX_FISH"
  
  assert_success
  assert_output --partial "datasource=custom.citrix"
}

@test "citrix version is valid format" {
  run run_fish_citrix "__citrix_get_version"
  
  assert_success
  # Citrix versions are: YY.MM.PATCH.BUILD (e.g., 25.08.10.111)
  [[ "$output" =~ ^[0-9]{2}\.[0-9]{2}\.[0-9]+\.[0-9]+$ ]]
}

# Citrix publishes the amd64 build as icaclient_<ver>_amd64.deb on some releases
# and icaclient-gcc-8_<ver>_amd64.deb on others. Both must resolve, or the
# installer silently finds nothing.

_citrix_page_fixture() {
  printf '<div class="ctx-download-entry">\n<a rel="//downloads.citrix.com/26543/%s?__gda__=exp=1">x</a>\n<li>SHA-256 - aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</li>\n</div>\n' "$@" >"$TEST_DIR/page.html"
}

_citrix_urls_from_fixture() {
  fish --no-config -c "
    source '$DEVBASE_CITRIX_FISH'
    function curl; cat '$TEST_DIR/page.html'; end
    __citrix_fetch_download_urls
  "
}

@test "download URLs resolve when Citrix uses the gcc-8 amd64 names" {
  _citrix_page_fixture "icaclient-gcc-8_26.04.10.1_amd64.deb" "ctxusb-gcc-8_26.04.10.1_amd64.deb"

  run _citrix_urls_from_fixture

  assert_success
  assert_output --partial "icaclient-gcc-8_26.04.10.1_amd64.deb"
  assert_output --partial "ctxusb-gcc-8_26.04.10.1_amd64.deb"
}

@test "download URLs prefer the plain amd64 name when Citrix publishes it" {
  _citrix_page_fixture "icaclient_26.04.10.1_amd64.deb" "icaclient-gcc-8_26.04.10.1_amd64.deb"

  run _citrix_urls_from_fixture

  assert_success
  assert_output --partial "icaclient_26.04.10.1_amd64.deb"
  refute_output --partial "icaclient-gcc-8"
}

@test "download URL lookup fails when no amd64 package is listed" {
  _citrix_page_fixture "icaclient_26.04.10.1_arm64.deb"

  run _citrix_urls_from_fixture

  assert_failure
}

@test "Citrix refuses a newer unpinned release and missing checksums" {
  _citrix_page_fixture "icaclient_99.01.1.1_amd64.deb"
  run _citrix_urls_from_fixture
  assert_failure

  printf '<div class="ctx-download-entry"><a rel="//downloads.citrix.com/1/icaclient_26.04.10.1_amd64.deb?token=test">x</a></div>\n' >"$TEST_DIR/page.html"
  run _citrix_urls_from_fixture
  assert_failure
}

@test "Citrix never borrows a checksum from an adjacent package" {
  printf '<div class="ctx-download-entry"><a rel="//downloads.citrix.com/1/icaclient_26.04.10.1_amd64.deb?token=test">x</a></div>\n' >"$TEST_DIR/page.html"
  printf '<div class="ctx-download-entry"><li>SHA-256 - aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</li></div>\n' >>"$TEST_DIR/page.html"
  run _citrix_urls_from_fixture
  assert_failure
}

@test "Citrix propagates APT failure with complete diagnostics" {
  run run_fish_citrix '
    function sudo
      printf "APT diagnostic %s\n" (seq 1 10)
      return 42
    end
    __citrix_install_deb /fixture/ctxusb.deb
  '
  assert_failure
  assert_output --partial 'APT diagnostic 1'
  assert_output --partial 'APT diagnostic 10'
  refute_output --partial '✓ Installed'
}

@test "Citrix rejects tampered packages before any privileged install" {
  run run_fish_citrix "
    function __citrix_fetch_download_urls
      printf 'https://downloads.citrix.com/1/icaclient_26.04.10.1_amd64.deb?token=test\taaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n'
    end
    function __citrix_download_file; printf tampered >\$argv[2]; end
    function __citrix_install_deb; echo UNEXPECTED_INSTALL; end
    __citrix_download_and_install '$TEST_DIR'
  "
  assert_failure
  assert_output --partial 'Checksum verification failed'
  refute_output --partial UNEXPECTED_INSTALL
}

@test "Citrix removes its private download directory after failure" {
  _fake_debian_amd64_tools
  run run_fish_citrix "
    function __citrix_configure_install_options; end
    function __citrix_download_and_install
      printf '%s' \$argv[1] > '$TEST_DIR/temp-path'
      test (stat -c %a \$argv[1]) = 700; or return 2
      return 1
    end
    devbase-citrix
  "
  assert_failure
  local directory
  directory=$(<"$TEST_DIR/temp-path")
  [[ "$directory" == /tmp/devbase-citrix.* ]]
  assert_dir_not_exists "$directory"
}

@test "Citrix verifies package identity and all downloads before installing" {
  # Builds and inspects a real .deb
  command -v dpkg-deb >/dev/null || skip "dpkg-deb is Debian/Ubuntu only"
  mkdir -p "$TEST_DIR/package/DEBIAN" "$TEST_DIR/downloads"
  printf 'Package: icaclient\nVersion: 26.04.10.1\nArchitecture: amd64\nMaintainer: Fixture <fixture@example.test>\nDescription: offline test\n' >"$TEST_DIR/package/DEBIAN/control"
  dpkg-deb --build "$TEST_DIR/package" "$TEST_DIR/package.deb"
  local digest
  digest=$(sha256sum "$TEST_DIR/package.deb")
  digest="${digest%% *}"
  run run_fish_citrix "
    function __citrix_fetch_download_urls
      printf 'https://downloads.citrix.com/1/icaclient_26.04.10.1_amd64.deb?token=test\t$digest\n'
      printf 'https://downloads.citrix.com/1/ctxusb_26.04.10.1_amd64.deb?token=test\t$digest\n'
    end
    function __citrix_download_file; cp '$TEST_DIR/package.deb' \$argv[2]; end
    function __citrix_install_deb; echo UNEXPECTED_INSTALL; end
    __citrix_download_and_install '$TEST_DIR/downloads'
  "
  assert_failure
  assert_output --partial 'Unexpected package identity'
  refute_output --partial UNEXPECTED_INSTALL
}

@test "Citrix stops before downloading when private directory creation fails" {
  _fake_debian_amd64_tools
  run run_fish_citrix '
    function __citrix_configure_install_options; end
    function mktemp; return 1; end
    function __citrix_download_and_install; echo UNEXPECTED_DOWNLOAD; end
    function rm; echo UNEXPECTED_REMOVE; end
    devbase-citrix
  '
  assert_failure
  assert_output --partial 'Failed to create a private download directory'
  refute_output --partial UNEXPECTED_DOWNLOAD
  refute_output --partial UNEXPECTED_REMOVE
}
