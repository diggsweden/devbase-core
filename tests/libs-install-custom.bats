#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016,SC2030,SC2031,SC2123,SC2153,SC2155,SC2218
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

bats_require_minimum_version 1.5.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'libs/bats-mock/stub'
load 'test_helper'

setup() {
  common_setup_isolated
  source_core_libs
  source "${DEVBASE_ROOT}/libs/utils.sh"
}

teardown() {
  # Unstub before deleting temp dir
  if declare -f unstub >/dev/null 2>&1; then
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/curl" ]] && unstub curl || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/jq" ]] && unstub jq || true
    [[ -L "${BATS_MOCK_BINDIR:-/tmp/bin}/git" ]] && unstub git || true
  fi
  
  common_teardown
}

@test "get_vscode_checksum fetches a pinned release checksum from versioned API" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  stub curl '-fsSL --connect-timeout 10 --max-time 30 https://update.code.visualstudio.com/api/versions/1.139.1/linux-deb-x64/stable : echo "{\"productVersion\":\"1.139.1\",\"sha256hash\":\"cc8e35cf69ff4c7e515e19fa981bf6aba41f61ddb61c79370e9fe460c5dbaf8b\"}"'

  run --separate-stderr get_vscode_checksum "1.139.1"
  assert_success
  assert_output "cc8e35cf69ff4c7e515e19fa981bf6aba41f61ddb61c79370e9fe460c5dbaf8b"
  unstub curl
}

@test "get_vscode_checksum requests metadata for the selected RPM architecture" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  stub curl '-fsSL --connect-timeout 10 --max-time 30 https://update.code.visualstudio.com/api/versions/1.139.1/linux-rpm-arm64/stable : echo "{\"productVersion\":\"1.139.1\",\"sha256hash\":\"d067f5cd1b4f9a94e0921cb869ede08db9cb1e289121f2f4657aec3822fd3f5e\"}"'

  run --separate-stderr get_vscode_checksum "1.139.1" "linux-rpm-arm64"
  assert_success
  assert_output "d067f5cd1b4f9a94e0921cb869ede08db9cb1e289121f2f4657aec3822fd3f5e"
  unstub curl
}

@test "get_vscode_checksum rejects another release or an invalid digest" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  local response
  for response in \
    '{"productVersion":"1.140.0","sha256hash":"cc8e35cf69ff4c7e515e19fa981bf6aba41f61ddb61c79370e9fe460c5dbaf8b"}' \
    '{"productVersion":"1.139.1","sha256hash":"abc123"}' \
    '{"productVersion":"1.139.1","sha256hash":null}'; do
    # shellcheck disable=SC2329
    curl() { printf '%s\n' "$response"; }
    run get_vscode_checksum "1.139.1"
    assert_failure
    assert_output ""
  done
}

@test "get_vscode_checksum fails when jq not available" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  # Override command_exists to return false for jq
  command_exists() {
    [[ "$1" != "jq" ]]
  }
  
  run get_vscode_checksum "1.85.1"
  assert_failure
}

@test "get_vscode_checksum validates version parameter" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  run get_vscode_checksum ""
  assert_failure
}

@test "get_oc_checksum fetches checksum from mirror" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  # shellcheck disable=SC2329
  get_checksum_from_manifest() { echo "abc123def456"; }

  result=$(get_oc_checksum "4.15.33")
  [[ "$result" == "abc123def456" ]]
}

@test "get_nerd_font_checksum returns checksum from manifest" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  # shellcheck disable=SC2329
  get_checksum_from_manifest() { echo "abc123"; }

  result=$(get_nerd_font_checksum "v3.4.0" "JetBrainsMono.zip")
  [[ "$result" == "abc123" ]]
}

@test "get_nerd_font_checksum uses SHA-256.txt only" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  # shellcheck disable=SC2329
  get_checksum_from_manifest() {
    printf '%s\n' "$1" >>"${TEST_DIR}/manifest-urls.log"
    echo "abc123"
  }

  run get_nerd_font_checksum "v3.4.0" "Monaspace.zip"
  assert_success
  assert_output "abc123"

  assert_file_exists "${TEST_DIR}/manifest-urls.log"
  run cat "${TEST_DIR}/manifest-urls.log"
  assert_success
  assert_output "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/SHA-256.txt"
}

@test "get_oc_checksum validates version parameter" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  run get_oc_checksum ""
  assert_failure
}

_setup_lazyvim_test() {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  export DEVBASE_INSTALL_LAZYVIM="true"
  export DEVBASE_THEME="everforest-dark"
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  # shellcheck disable=SC2154 # TOOL_VERSIONS is associative, declared in install-custom.sh
  TOOL_VERSIONS[lazyvim]="test-pin"

  # shellcheck disable=SC2329
  git() { _mock_lazyvim_git "$@"; }
}

_mock_lazyvim_git() {
  printf '%s\n' "$*" >>"${TEST_DIR}/lazyvim-git.log"
  case "$1" in
    clone)
      mkdir -p "$4/.git" "$4/lua/plugins"
      printf '%s\n' 'unconfigured main' >"$4/init.lua"
      ;;
    -C)
      [[ "$3 $4 $5" == "checkout --quiet test-pin" ]] || return 1
      printf '%s\n' 'pinned starter' >"$2/init.lua"
      ;;
    *) return 1 ;;
  esac
}

_assert_lazyvim_staging_clean() {
  run find "$XDG_CONFIG_HOME" -mindepth 1 -maxdepth 1 ! -name nvim
  assert_success
  assert_output ""
}

_assert_lazyvim_not_published() {
  [[ ! -e "${XDG_CONFIG_HOME}/nvim" && ! -L "${XDG_CONFIG_HOME}/nvim" ]]
  _assert_lazyvim_staging_clean
}

@test "install_lazyvim skips when user preference is false or unset" {
  _setup_lazyvim_test
  unset DEVBASE_THEME DEVBASE_DOT
  export DEVBASE_INSTALL_LAZYVIM="false"

  run install_lazyvim
  assert_success
  assert_output --partial "skipped by user preference"
  _assert_lazyvim_not_published

  unset DEVBASE_INSTALL_LAZYVIM
  run install_lazyvim
  assert_success
  assert_output --partial "skipped by user preference"
  _assert_lazyvim_not_published
  assert_not_exists "${TEST_DIR}/lazyvim-git.log"
}

@test "install_lazyvim preserves existing nvim config without backup or initialization" {
  _setup_lazyvim_test
  mkdir -p "${XDG_CONFIG_HOME}/nvim"
  echo "existing config" > "${XDG_CONFIG_HOME}/nvim/init.lua"
  unset DEVBASE_THEME DEVBASE_DOT

  run install_lazyvim
  assert_success
  assert_output --partial "Existing nvim configuration preserved"
  run cat "${XDG_CONFIG_HOME}/nvim/init.lua"
  assert_output "existing config"
  assert_not_exists "${XDG_CONFIG_HOME}/nvim/lua"
  assert_not_exists "${TEST_DIR}/lazyvim-git.log"
  _assert_lazyvim_staging_clean
}

@test "install_lazyvim preserves an empty nvim directory" {
  _setup_lazyvim_test
  mkdir -p "${XDG_CONFIG_HOME}/nvim"

  run install_lazyvim
  assert_success
  assert_output --partial "Existing nvim configuration preserved"
  run find "${XDG_CONFIG_HOME}/nvim" -mindepth 1
  assert_success
  assert_output ""
  assert_not_exists "${TEST_DIR}/lazyvim-git.log"
  _assert_lazyvim_staging_clean
}

@test "install_lazyvim preserves a file at the nvim path" {
  _setup_lazyvim_test
  echo "existing file" >"${XDG_CONFIG_HOME}/nvim"

  run install_lazyvim
  assert_success
  run cat "${XDG_CONFIG_HOME}/nvim"
  assert_output "existing file"
  assert_not_exists "${TEST_DIR}/lazyvim-git.log"
  _assert_lazyvim_staging_clean
}

@test "install_lazyvim preserves nvim symlinks to directories files and missing targets" {
  _setup_lazyvim_test
  mkdir -p "${TEST_DIR}/existing-config"
  echo "existing config" >"${TEST_DIR}/existing-config/init.lua"
  echo "existing file" >"${TEST_DIR}/existing-file"

  local target
  for target in existing-config existing-file missing-config; do
    export XDG_CONFIG_HOME="${TEST_DIR}/config-${target}"
    mkdir -p "$XDG_CONFIG_HOME"
    ln -s "${TEST_DIR}/${target}" "${XDG_CONFIG_HOME}/nvim"

    run install_lazyvim
    assert_success
    assert_output --partial "Existing nvim configuration preserved"
    [[ -L "${XDG_CONFIG_HOME}/nvim" ]]
    [[ "$(readlink "${XDG_CONFIG_HOME}/nvim")" == "${TEST_DIR}/${target}" ]]
    _assert_lazyvim_staging_clean
  done

  run cat "${TEST_DIR}/existing-config/init.lua"
  assert_output "existing config"
  assert_not_exists "${TEST_DIR}/existing-config/lua"
  run cat "${TEST_DIR}/existing-file"
  assert_output "existing file"
  assert_not_exists "${TEST_DIR}/missing-config"
  assert_not_exists "${TEST_DIR}/lazyvim-git.log"
}

@test "install_lazyvim publishes a pinned starter with dark theme and treesitter" {
  _setup_lazyvim_test
  # The config root itself may be absent and may contain spaces.
  export XDG_CONFIG_HOME="${TEST_DIR}/fresh config"

  run install_lazyvim
  assert_success
  assert_output --partial "LazyVim starter installed (test-pin)"
  run cat "${XDG_CONFIG_HOME}/nvim/init.lua"
  assert_output "pinned starter"
  assert_file_contains "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua" "vim.opt.background = 'dark'"
  cmp "${DEVBASE_DOT}/.config/nvim/lua/plugins/treesitter.lua" "${XDG_CONFIG_HOME}/nvim/lua/plugins/treesitter.lua"
  assert_not_exists "${XDG_CONFIG_HOME}/nvim/.git"
  _assert_lazyvim_staging_clean
}

@test "install_lazyvim configures every light theme background" {
  _setup_lazyvim_test
  local theme
  for theme in everforest-light catppuccin-latte tokyonight-day gruvbox-light solarized-light; do
    export DEVBASE_THEME="$theme" XDG_CONFIG_HOME="${TEST_DIR}/config-${theme}"
    run install_lazyvim
    assert_success
    assert_file_contains "${XDG_CONFIG_HOME}/nvim/lua/plugins/colorscheme.lua" "vim.opt.background = 'light'"
    _assert_lazyvim_staging_clean
  done
}

@test "install_lazyvim cleans a partial failed clone without publishing" {
  _setup_lazyvim_test
  # shellcheck disable=SC2329
  git() {
    _mock_lazyvim_git "$@" || return 1
    return 1
  }

  run install_lazyvim
  assert_failure
  assert_output --partial "Failed to clone LazyVim starter"
  _assert_lazyvim_not_published
}

@test "install_lazyvim aborts a failed checkout instead of publishing main" {
  _setup_lazyvim_test
  # shellcheck disable=SC2329
  git() {
    [[ "$1" != "-C" ]] || return 1
    _mock_lazyvim_git "$@"
  }

  run install_lazyvim
  assert_failure
  assert_output --partial "Failed to checkout LazyVim starter test-pin"
  _assert_lazyvim_not_published
}

@test "install_lazyvim cleans a partial failed render without publishing" {
  _setup_lazyvim_test
  # shellcheck disable=SC2329
  envsubst_preserve_undefined() {
    echo "partial render" >"$2"
    return 1
  }

  run install_lazyvim
  assert_failure
  assert_output --partial "Failed to configure LazyVim colorscheme"
  _assert_lazyvim_not_published
}

@test "install_lazyvim cleans a partial failed treesitter copy without publishing" {
  _setup_lazyvim_test
  # shellcheck disable=SC2329
  cp() {
    echo "partial copy" >"${@: -1}"
    return 1
  }

  run install_lazyvim
  assert_failure
  assert_output --partial "Failed to configure LazyVim treesitter"
  _assert_lazyvim_not_published
}

@test "install_lazyvim fails without publishing when staged git metadata cannot be removed" {
  _setup_lazyvim_test
  # shellcheck disable=SC2329
  git() {
    _mock_lazyvim_git "$@" || return 1
    if [[ "$1" == "-C" ]]; then
      rmdir "$2/.git"
      ln -s "${TEST_DIR}/protected-git" "$2/.git"
    fi
  }
  mkdir -p "${TEST_DIR}/protected-git"
  echo "keep" >"${TEST_DIR}/protected-git/config"

  run install_lazyvim
  assert_failure
  _assert_lazyvim_not_published
  run cat "${TEST_DIR}/protected-git/config"
  assert_output "keep"
}

@test "install_lazyvim cleans staging when publication fails" {
  _setup_lazyvim_test
  # shellcheck disable=SC2329
  mv() { return 1; }

  run install_lazyvim
  assert_failure
  assert_output --partial "Failed to publish LazyVim starter"
  _assert_lazyvim_not_published
}

@test "install_lazyvim preserves targets created just before publication" {
  _setup_lazyvim_test
  local target_type
  for target_type in empty-directory directory file symlink dangling-symlink; do
    export XDG_CONFIG_HOME="${TEST_DIR}/race-${target_type}"
    # Inject the race immediately before the real GNU mv, after preparation.
    # shellcheck disable=SC2329
    mv() {
      local target="${XDG_CONFIG_HOME}/nvim"
      case "$target_type" in
        empty-directory) mkdir "$target" ;;
        directory)
          mkdir "$target"
          echo "race config" >"$target/init.lua"
          ;;
        file) echo "race config" >"$target" ;;
        symlink)
          mkdir -p "${TEST_DIR}/race-config"
          echo "race config" >"${TEST_DIR}/race-config/init.lua"
          ln -s "${TEST_DIR}/race-config" "$target"
          ;;
        dangling-symlink) ln -s "${TEST_DIR}/race-missing" "$target" ;;
      esac
      command mv "$@"
    }

    run install_lazyvim
    assert_success
    assert_output --partial "Existing nvim configuration preserved"
    refute_output --partial "LazyVim starter installed"
    case "$target_type" in
      empty-directory)
        run find "${XDG_CONFIG_HOME}/nvim" -mindepth 1
        assert_success
        assert_output ""
        ;;
      directory|symlink)
        run cat "${XDG_CONFIG_HOME}/nvim/init.lua"
        assert_output "race config"
        assert_not_exists "${XDG_CONFIG_HOME}/nvim/lua"
        assert_not_exists "${XDG_CONFIG_HOME}/nvim/nvim"
        ;;
      file)
        run cat "${XDG_CONFIG_HOME}/nvim"
        assert_output "race config"
        ;;
      dangling-symlink)
        [[ -L "${XDG_CONFIG_HOME}/nvim" ]]
        [[ "$(readlink "${XDG_CONFIG_HOME}/nvim")" == "${TEST_DIR}/race-missing" ]]
        assert_not_exists "${TEST_DIR}/race-missing"
        ;;
    esac
    if [[ "$target_type" == "symlink" ]]; then
      [[ -L "${XDG_CONFIG_HOME}/nvim" ]]
      [[ "$(readlink "${XDG_CONFIG_HOME}/nvim")" == "${TEST_DIR}/race-config" ]]
    fi
    _assert_lazyvim_staging_clean
  done
}

@test "_determine_font_details returns correct font info" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  result=$(_determine_font_details "monaspace")
  [[ "$result" =~ MonaspaceNerdFont ]]
  
  result=$(_determine_font_details "firacode")
  [[ "$result" =~ FiraCode ]]
}

@test "_determine_font_details keeps timeout and family as separate fields" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  local font_name font_zip_name font_dir_name font_display_name timeout font_family_name
  IFS='|' read -r font_name font_zip_name font_dir_name font_display_name timeout font_family_name <<<"$(_determine_font_details "monaspace")"

  [[ "$timeout" == "120" ]]
  [[ "$font_family_name" == "MonaspiceNe Nerd Font Mono" ]]
}

@test "_download_all_fonts_to_cache keeps timeout separate from font family" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  get_font_ids() { printf '%s\n' "monaspace"; }
  _download_font_to_cache() {
    local timeout="$4"
    [[ "$timeout" == "120" ]]
  }

  run _download_all_fonts_to_cache "${TEST_DIR}/cache" "v3.4.0"
  assert_success
}

@test "_is_wayland_session detects Wayland" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  
  export WAYLAND_DISPLAY="wayland-0"
  
  run _is_wayland_session
  assert_success
  
  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE="wayland"
  
  run _is_wayland_session
  assert_success
}

@test "_download_intellij_archive only echoes tar path" {
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export DEVBASE_SELECTED_PACKS=""

  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom: {}
packs: {}
EOF

  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  download_with_cache() {
    echo "download output"
    echo "download error" >&2
    return 0
  }

  run --separate-stderr _download_intellij_archive "2025.3.3" "${TEST_DIR}"
  assert_success
  assert_output "${TEST_DIR}/intellij-idea.tar.gz"
  [[ "$stderr" == *"Downloading IntelliJ IDEA 2025.3.3"* ]]
  [[ "$stderr" == *"download output"* ]]
  [[ "$stderr" == *"download error"* ]]
}

@test "install_intellij_idea updates when version differs" {
  export DEVBASE_INSTALL_INTELLIJ="true"
  export DEVBASE_DOT="${TEST_DIR}/dot"
  export DEVBASE_SELECTED_PACKS=""
  export PACKAGES_YAML="${DEVBASE_DOT}/.config/devbase/packages.yaml"
  export _DEVBASE_TEMP="${TEST_DIR}/tmp"

  mkdir -p "${DEVBASE_DOT}/.config/devbase"
  cat > "${DEVBASE_DOT}/.config/devbase/packages.yaml" << 'EOF'
core:
  custom:
    intellij_idea: { version: "2025.3.2", installer: "install_intellij_idea" }
packs: {}
EOF

  mkdir -p "${HOME}/.local/share/JetBrains/IntelliJIdea"
  cat > "${HOME}/.local/share/JetBrains/IntelliJIdea/product-info.json" << 'EOF'
{
  "name": "IntelliJ IDEA",
  "version": "2025.2.0"
}
EOF

  source "${DEVBASE_ROOT}/libs/parse-packages.sh"
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  _download_intellij_archive() { echo "${TEST_DIR}/fake.tar.gz"; }
  _extract_and_install_intellij() {
    local extract_dir="$2"
    mkdir -p "$extract_dir/IntelliJIdea"
    echo "$extract_dir/IntelliJIdea"
  }
  _configure_intellij_vmoptions() { :; }
  _create_intellij_desktop_file() { echo "$1" >"${TEST_DIR}/idea-desktop"; }

  run install_intellij_idea
  assert_success

  run ls "${HOME}/.local/share/JetBrains/IntelliJIdea-old"*
  assert_success
  assert_file_exists "${TEST_DIR}/idea-desktop"
}

@test "_is_wayland_session detects X11" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE="x11"

  run _is_wayland_session
  assert_failure
}

@test "_configure_intellij_vmoptions enables Wayland with shadow fix" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  export WAYLAND_DISPLAY="wayland-0"
  local template="${DEVBASE_ROOT}/dot/.config/devbase/intellij-vmoptions.template"

  _configure_intellij_vmoptions "2025.2" "$template"

  local vmoptions="${HOME}/.config/JetBrains/IntelliJIdea2025.2/idea64.vmoptions"
  assert_file_exists "$vmoptions"
  run cat "$vmoptions"
  assert_output --partial "-Dawt.toolkit.name=WLToolkit"
  assert_output --partial "-Dsun.awt.wl.Shadow=false"
}

@test "_configure_intellij_vmoptions omits Wayland on X11" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE="x11"
  local template="${DEVBASE_ROOT}/dot/.config/devbase/intellij-vmoptions.template"

  _configure_intellij_vmoptions "2025.2" "$template"

  local vmoptions="${HOME}/.config/JetBrains/IntelliJIdea2025.2/idea64.vmoptions"
  assert_file_exists "$vmoptions"
  run cat "$vmoptions"
  refute_output --partial "WLToolkit"
  refute_output --partial "wl.Shadow"
}

@test "_configure_intellij_vmoptions works without template" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"

  export WAYLAND_DISPLAY="wayland-0"

  _configure_intellij_vmoptions "2025.2" "/nonexistent/template"

  local vmoptions="${HOME}/.config/JetBrains/IntelliJIdea2025.2/idea64.vmoptions"
  assert_file_exists "$vmoptions"
  run cat "$vmoptions"
  assert_output --partial "-Dawt.toolkit.name=WLToolkit"
  assert_output --partial "-Dsun.awt.wl.Shadow=false"
}

@test "_configure_intellij_vmoptions preserves personal settings and dangling links" {
  source "${DEVBASE_ROOT}/libs/install-custom.sh"
  export XDG_SESSION_TYPE=wayland
  local target="${XDG_CONFIG_HOME}/JetBrains/IntelliJIdea2025.2/idea64.vmoptions"
  mkdir -p "$(dirname "$target")"
  echo '-Xmx8192m' >"$target"
  run _configure_intellij_vmoptions "2025.2" "${DEVBASE_ROOT}/dot/.config/devbase/intellij-vmoptions.template"
  assert_success
  assert_equal "$(cat "$target")" '-Xmx8192m'
  run _configure_intellij_vmoptions "2025.2" "${TEST_DIR}/missing.template"
  assert_success
  assert_equal "$(cat "$target")" '-Xmx8192m'

  rm "$target"
  touch "$target"
  run _configure_intellij_vmoptions "2025.2" "${TEST_DIR}/missing.template"
  assert_success
  assert [ ! -s "$target" ]

  rm "$target"
  ln -s "${TEST_DIR}/missing.vmoptions" "$target"
  run _configure_intellij_vmoptions "2025.2" "${TEST_DIR}/missing.template"
  assert_success
  assert_symlink_to "${TEST_DIR}/missing.vmoptions" "$target"
  assert_file_not_exists "${TEST_DIR}/missing.vmoptions"
}

# get_oc_checksum, get_vscode_checksum and get_gum_checksum are each tested on
# their own; these assert the digest they return reaches the download.

_capture_download_args() {
  # $1 = extra setup, $2 = call under test
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    export _DEVBASE_TEMP='${TEST_DIR}/tmp'
    export XDG_BIN_HOME='${TEST_DIR}/bin'
    export XDG_CACHE_HOME='${TEST_DIR}/cache'
    mkdir -p \"\$_DEVBASE_TEMP\" \"\$XDG_BIN_HOME\" \"\$XDG_CACHE_HOME\"
    source '${DEVBASE_ROOT}/libs/constants.sh'
    source '${DEVBASE_ROOT}/libs/define-colors.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/validation.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/ui/ui-helpers.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/utils.sh' >/dev/null 2>&1
    source '${DEVBASE_ROOT}/libs/install-custom.sh' >/dev/null 2>&1
    declare -gA TOOL_VERSIONS
    add_install_warning() { :; }
    command_exists() { return 1; }
    # install_k3s probes with `command -v k3s` directly, so without this the
    # test result depends on whether the host happens to have k3s installed.
    command() { [[ \$1 == '-v' ]] && return 1; builtin command \$@; }
    # Record the arguments and stop before anything is unpacked or run.
    download_file() { printf 'ARGS:%s\n' \"\$*\"; return 1; }
    download_with_cache() { printf 'ARGS:%s\n' \"\$*\"; return 1; }
    ${1}
    ${2}
  "
}

@test "install_oc_kubectl passes the fetched checksum to the download" {
  _capture_download_args \
    "TOOL_VERSIONS[oc]='4.22.10'; get_oc_checksum() { echo 'deadbeefoc'; }" \
    "install_oc_kubectl"

  assert_output --partial "ARGS:"
  assert_output --partial "deadbeefoc"
}

# DBeaver renamed its Linux assets, and nothing tracks the URL shape - Renovate
# only moves the version - so a stale name here 404s at install time.
@test "install_dbeaver requests the published deb asset name" {
  _capture_download_args \
    "TOOL_VERSIONS[dbeaver]='26.1.4'; _get_custom_pkg_format() { echo deb; }" \
    "install_dbeaver"

  assert_output --partial "/26.1.4/dbeaver-ce-26.1.4-linux-x86_64.deb"
}

@test "install_dbeaver requests the published rpm asset name" {
  _capture_download_args \
    "TOOL_VERSIONS[dbeaver]='26.1.4'; _get_custom_pkg_format() { echo rpm; }" \
    "install_dbeaver"

  assert_output --partial "/26.1.4/dbeaver-ce-26.1.4-linux-x86_64.rpm"
}

@test "install_k3s forwards a pinned installer checksum to the download" {
  # Unlike the other installers, k3s does not fetch a digest; it only honours
  # DEVBASE_K3S_INSTALL_SHA256.
  _capture_download_args \
    "TOOL_VERSIONS[k3s]='v1.36.3+k3s1'; export DEVBASE_K3S_INSTALL_SHA256='deadbeefk3s'" \
    "install_k3s"

  assert_output --partial "deadbeefk3s"
}

@test "install_k3s downloads the installer unverified when nothing is pinned" {
  # Pins current behaviour: with DEVBASE_K3S_INSTALL_SHA256 unset the k3s
  # install.sh is fetched with an empty checksum and then executed with sh.
  # The URL is allowlisted in DEVBASE_STRICT_CHECKSUMS_ALLOWLIST, so
  # download_file permits it.
  _capture_download_args \
    "TOOL_VERSIONS[k3s]='v1.36.3+k3s1'; unset DEVBASE_K3S_INSTALL_SHA256" \
    "install_k3s"

  assert_output --partial "install.sh"
  refute_output --partial "deadbeef"
}

@test "install_gum passes the fetched checksum to the download" {
  _capture_download_args \
    "TOOL_VERSIONS[gum]='2.0.0'
     _get_custom_pkg_format() { echo deb; }
     get_deb_arch() { echo amd64; }
     get_gum_checksum() { echo 'deadbeefgum'; }" \
    "install_gum"

  assert_output --partial "deadbeefgum"
  assert_output --partial "/v2.0.0/gum_2.0.0_amd64.deb"
}

@test "install_gum requests the published v2 rpm asset name" {
  _capture_download_args \
    "TOOL_VERSIONS[gum]='2.0.0'
     _get_custom_pkg_format() { echo rpm; }
     get_deb_arch() { echo amd64; }
     get_rpm_arch() { echo x86_64; }
     get_gum_checksum() { echo 'deadbeefgum'; }" \
    "install_gum"

  assert_output --partial "/v2.0.0/gum-2.0.0-1.x86_64.rpm"
  assert_output --partial "deadbeefgum"
}

_capture_bootstrap_gum_url() {
  _capture_download_args \
    "source '${DEVBASE_ROOT}/libs/bootstrap/bootstrap-ui.sh'
     NON_INTERACTIVE=false
     _DEVBASE_ENV='${1}'
     get_deb_arch() { echo '${2}'; }
     get_rpm_arch() { echo '${3}'; }
     curl() { printf '%s\\n' \"\$*\" >'${TEST_DIR}/gum-url'; return 1; }" \
    "bootstrap_gum"

  assert_failure
  run cat "${TEST_DIR}/gum-url"
  assert_success
}

@test "bootstrap_gum requests the published v2 deb asset name" {
  _capture_bootstrap_gum_url ubuntu amd64 x86_64
  assert_output --partial "/v2.0.1/gum_2.0.1_amd64.deb"
}

@test "bootstrap_gum requests the published v2 arm64 rpm asset name" {
  _capture_bootstrap_gum_url fedora arm64 aarch64
  assert_output --partial "/v2.0.1/gum-2.0.1-1.aarch64.rpm"
}
