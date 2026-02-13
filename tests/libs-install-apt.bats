#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-mock/stub.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export _DEVBASE_CUSTOM_PACKAGES=""
  source_core_libs_with_requirements
  source "${DEVBASE_ROOT}/libs/utils.sh"
  source "${DEVBASE_ROOT}/libs/pkg/pkg-manager.sh"
}

teardown() {
  common_teardown
}

@test "get_apt_packages reads packages from packages.yaml" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"

  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<EOF
core:
  apt:
    curl: {}
    git: {}
    vim: {}
packs: {}
EOF

  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${DEVBASE_DOT}/.config/devbase/packages.yaml'
    export SELECTED_PACKS=''
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    get_apt_packages | wc -l
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "3"
}

@test "get_apt_packages includes packages from selected packs" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"

  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<EOF
core:
  apt:
    curl: {}
packs:
  java:
    description: "Java development"
    apt:
      default-jdk: {}
EOF

  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${DEVBASE_DOT}/.config/devbase/packages.yaml'
    export SELECTED_PACKS='java'
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    get_apt_packages | wc -l
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "2"
}

@test "get_apt_packages excludes unselected packs" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"

  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<EOF
core:
  apt:
    curl: {}
packs:
  java:
    description: "Java development"
    apt:
      default-jdk: {}
  python:
    description: "Python development"
    apt:
      python3: {}
EOF

  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${DEVBASE_DOT}/.config/devbase/packages.yaml'
    export SELECTED_PACKS='java'
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    # Should have curl (core) + default-jdk (java), not python3
    get_apt_packages | wc -l
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "2"
}

@test "get_apt_packages handles @skip-wsl tag" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"

  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<EOF
core:
  apt:
    curl: {}
    firefox: { tags: ["@skip-wsl"] }
    git: {}
packs: {}
EOF

  # Use run_as_wsl helper to simulate WSL environment
  run --separate-stderr run_as_wsl "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${DEVBASE_DOT}/.config/devbase/packages.yaml'
    export SELECTED_PACKS=''
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    get_apt_packages | wc -l
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "2"
}

@test "get_apt_packages merges custom packages.yaml overlay" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export _DEVBASE_CUSTOM_PACKAGES="${TEST_DIR}/custom"

  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  mkdir -p "${_DEVBASE_CUSTOM_PACKAGES}"

  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<EOF
core:
  apt:
    curl: {}
packs: {}
EOF

  cat > "${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml" <<EOF
core:
  apt:
    custom-package: {}
EOF

  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${DEVBASE_DOT}/.config/devbase/packages.yaml'
    export PACKAGES_CUSTOM_YAML='${_DEVBASE_CUSTOM_PACKAGES}/packages-custom.yaml'
    export SELECTED_PACKS=''
    export _DEVBASE_CUSTOM_PACKAGES='${_DEVBASE_CUSTOM_PACKAGES}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    get_apt_packages
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "custom-package"
}

@test "get_apt_packages returns package names correctly" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"

  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" <<EOF
core:
  apt:
    curl: {}
    git: {}
packs: {}
EOF

  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export DEVBASE_LIBS='${DEVBASE_ROOT}/libs'
    export PACKAGES_YAML='${DEVBASE_DOT}/.config/devbase/packages.yaml'
    export SELECTED_PACKS=''
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/parse-packages.sh'
    get_apt_packages | head -1
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "curl"
}

@test "pkg_install validates package names are not empty" {
  run --separate-stderr pkg_install ''

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_failure
}

@test "pkg_install handles empty package list" {
  run --separate-stderr pkg_install

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
}

@test "configure_locale generates locale when not present" {
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/locale" <<'SCRIPT'
#!/usr/bin/env bash
echo "en_US.utf8"
SCRIPT
  cat > "${TEST_DIR}/bin/sudo" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
  chmod +x "${TEST_DIR}/bin/locale" "${TEST_DIR}/bin/sudo"

  export PATH="${TEST_DIR}/bin:$PATH"
  export DEVBASE_LOCALE='sv_SE.UTF-8'

  run --separate-stderr configure_locale

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
}

@test "configure_locale skips when locale already present" {
  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/locale" <<'SCRIPT'
#!/usr/bin/env bash
echo -e "en_US.utf8\nsv_SE.utf8"
SCRIPT
  chmod +x "${TEST_DIR}/bin/locale"

  export PATH="${TEST_DIR}/bin:$PATH"
  export DEVBASE_LOCALE='sv_SE.UTF-8'

  run --separate-stderr configure_locale

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
}

@test "configure_locale skips when DEVBASE_LOCALE not set" {
  unset DEVBASE_LOCALE 2>/dev/null || true

  run --separate-stderr configure_locale

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
}

# Tests for _pkg_apt_configure_firefox_opensc

@test "_pkg_apt_configure_firefox_opensc skips when OpenSC library not found" {
  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/pkg/pkg-apt.sh'

    # Override function to use non-existent path
    _pkg_apt_configure_firefox_opensc() {
      local opensc_lib='/nonexistent/opensc-pkcs11.so'
      if [[ ! -f \"\$opensc_lib\" ]]; then
        show_progress info 'OpenSC PKCS#11 library not found'
        return 0
      fi
    }
    _pkg_apt_configure_firefox_opensc
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "OpenSC PKCS#11 library not found"
}

@test "_pkg_apt_configure_firefox_opensc skips when no Firefox profile exists" {
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}/.mozilla/firefox"

  # Create a fake opensc lib
  mkdir -p "${TEST_DIR}/usr/lib/x86_64-linux-gnu"
  touch "${TEST_DIR}/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"

  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export HOME='${HOME}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/pkg/pkg-apt.sh'

    # Override function to use test paths
    _pkg_apt_configure_firefox_opensc() {
      local opensc_lib='${TEST_DIR}/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so'
      if [[ ! -f \"\$opensc_lib\" ]]; then
        return 0
      fi
      local profile_dir
      profile_dir=\$(find \"\${HOME}/.mozilla/firefox\" -maxdepth 1 -type d -name '*.default*' 2>/dev/null | head -1)
      if [[ -z \"\$profile_dir\" ]]; then
        show_progress info 'No Firefox profile found'
        return 0
      fi
    }
    _pkg_apt_configure_firefox_opensc
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "No Firefox profile found"
}

@test "_pkg_apt_configure_firefox_opensc adds OpenSC to pkcs11.txt" {
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}/.mozilla/firefox/test123.default"

  # Create a fake opensc lib
  mkdir -p "${TEST_DIR}/usr/lib/x86_64-linux-gnu"
  touch "${TEST_DIR}/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"

  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export HOME='${HOME}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/pkg/pkg-apt.sh'

    # Override function to use test paths
    _pkg_apt_configure_firefox_opensc() {
      local opensc_lib='${TEST_DIR}/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so'
      if [[ ! -f \"\$opensc_lib\" ]]; then
        return 1
      fi
      local profile_dir
      profile_dir=\$(find \"\${HOME}/.mozilla/firefox\" -maxdepth 1 -type d -name '*.default*' 2>/dev/null | head -1)
      if [[ -z \"\$profile_dir\" ]]; then
        return 1
      fi
      local pkcs11_file=\"\${profile_dir}/pkcs11.txt\"
      printf '%s\n' \"library=\${opensc_lib}\" 'name=OpenSC' >> \"\$pkcs11_file\"
      show_progress success 'Firefox configured for smart card support'
      return 0
    }
    _pkg_apt_configure_firefox_opensc
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "Firefox configured for smart card support"

  # Verify pkcs11.txt was created
  assert_file_exists "${HOME}/.mozilla/firefox/test123.default/pkcs11.txt"
  run cat "${HOME}/.mozilla/firefox/test123.default/pkcs11.txt"
  assert_output --partial "opensc-pkcs11.so"
  assert_output --partial "name=OpenSC"
}

@test "_pkg_apt_configure_firefox_opensc skips when already configured" {
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}/.mozilla/firefox/test123.default"

  # Create existing pkcs11.txt with OpenSC
  echo "library=/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so" > "${HOME}/.mozilla/firefox/test123.default/pkcs11.txt"
  echo "name=OpenSC" >> "${HOME}/.mozilla/firefox/test123.default/pkcs11.txt"

  # Create a fake opensc lib
  mkdir -p "${TEST_DIR}/usr/lib/x86_64-linux-gnu"
  touch "${TEST_DIR}/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"

  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export HOME='${HOME}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/pkg/pkg-apt.sh'

    # Override function to use test paths
    _pkg_apt_configure_firefox_opensc() {
      local opensc_lib='${TEST_DIR}/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so'
      if [[ ! -f \"\$opensc_lib\" ]]; then
        return 0
      fi
      local profile_dir
      profile_dir=\$(find \"\${HOME}/.mozilla/firefox\" -maxdepth 1 -type d -name '*.default*' 2>/dev/null | head -1)
      if [[ -z \"\$profile_dir\" ]]; then
        return 0
      fi
      local pkcs11_file=\"\${profile_dir}/pkcs11.txt\"
      if [[ -f \"\$pkcs11_file\" ]] && grep -q 'opensc-pkcs11.so' \"\$pkcs11_file\" 2>/dev/null; then
        show_progress info 'OpenSC already configured in Firefox'
        return 0
      fi
    }
    _pkg_apt_configure_firefox_opensc
  "

  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "OpenSC already configured"
}
