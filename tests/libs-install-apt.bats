#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-mock/stub.bash"

setup() {
  TEST_DIR="$(temp_make)"
  export TEST_DIR
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export _DEVBASE_CUSTOM_PACKAGES=""
  
  source "${DEVBASE_ROOT}/libs/define-colors.sh"
  source "${DEVBASE_ROOT}/libs/validation.sh"
  source "${DEVBASE_ROOT}/libs/ui-helpers.sh"
  source "${DEVBASE_ROOT}/libs/check-requirements.sh"
  source "${DEVBASE_ROOT}/libs/utils.sh"
  source "${DEVBASE_ROOT}/libs/install-apt.sh"
}

teardown() {
  temp_del "$TEST_DIR"
}

@test "load_apt_packages reads packages from default file" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  
  cat > "${DEVBASE_DOT}/.config/devbase/apt-packages.txt" <<EOF
curl
git
vim
EOF
  
  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/install-apt.sh'
    load_apt_packages
    echo \${#APT_PACKAGES_ALL[@]}
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "3"
}

@test "load_apt_packages skips comment lines" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  
  cat > "${DEVBASE_DOT}/.config/devbase/apt-packages.txt" <<EOF
# This is a comment
curl
# Another comment
git
EOF
  
  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/install-apt.sh'
    load_apt_packages
    echo \${#APT_PACKAGES_ALL[@]}
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "2"
}

@test "load_apt_packages skips empty lines" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  
  cat > "${DEVBASE_DOT}/.config/devbase/apt-packages.txt" <<EOF
curl

git

EOF
  
  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/install-apt.sh'
    load_apt_packages
    echo \${#APT_PACKAGES_ALL[@]}
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "2"
}

@test "load_apt_packages handles @skip-wsl tag" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  
  cat > "${DEVBASE_DOT}/.config/devbase/apt-packages.txt" <<EOF
curl
firefox # @skip-wsl
git
EOF

  mkdir -p "${TEST_DIR}/bin"
  cat > "${TEST_DIR}/bin/uname" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "-r" ]]; then
  echo "5.10.0-microsoft-standard"
else
  /usr/bin/uname "$@"
fi
SCRIPT
  chmod +x "${TEST_DIR}/bin/uname"
  
  run --separate-stderr bash -c "
    export PATH='${TEST_DIR}/bin:/usr/bin:/bin:\$PATH'
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/install-apt.sh'
    load_apt_packages
    echo \${#APT_PACKAGES_ALL[@]}
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output "2"
}

@test "load_apt_packages uses custom package list when available" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export _DEVBASE_CUSTOM_PACKAGES="${TEST_DIR}/custom"
  
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  mkdir -p "${_DEVBASE_CUSTOM_PACKAGES}"
  
  echo "curl" > "${DEVBASE_DOT}/.config/devbase/apt-packages.txt"
  echo "custom-package" > "${_DEVBASE_CUSTOM_PACKAGES}/apt-packages.txt"
  
  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export _DEVBASE_CUSTOM_PACKAGES='${_DEVBASE_CUSTOM_PACKAGES}'
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/install-apt.sh'
    load_apt_packages
    echo \${APT_PACKAGES_ALL[0]}
  "
  
  [ "x$BATS_TEST_COMPLETED" = "x" ] && echo "o:'${output}' e:'${stderr}'"
  assert_success
  assert_output --partial "custom-package"
}

@test "load_apt_packages trims whitespace from package names" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  
  cat > "${DEVBASE_DOT}/.config/devbase/apt-packages.txt" <<EOF
  curl  
   git   
EOF
  
  run --separate-stderr bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export DEVBASE_DOT='${DEVBASE_DOT}'
    export _DEVBASE_CUSTOM_PACKAGES=''
    source '${DEVBASE_ROOT}/libs/define-colors.sh'
    source '${DEVBASE_ROOT}/libs/validation.sh'
    source '${DEVBASE_ROOT}/libs/ui-helpers.sh'
    source '${DEVBASE_ROOT}/libs/check-requirements.sh'
    source '${DEVBASE_ROOT}/libs/install-apt.sh'
    load_apt_packages
    echo \${APT_PACKAGES_ALL[0]}
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
