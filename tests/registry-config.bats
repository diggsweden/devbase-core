#!/usr/bin/env bats

# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT
# shellcheck disable=SC1090,SC1091,SC2016,SC2030,SC2031,SC2034,SC2153,SC2317,SC2329

bats_require_minimum_version 1.13.0
load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"
load "${BATS_TEST_DIRNAME}/test_helper.bash"

setup() {
  common_setup_isolated
  source_core_libs_with_requirements
  export DEVBASE_DOT="${DEVBASE_ROOT}/dot"
  export _DEVBASE_TEMP="$TEST_DIR"
  export DEVBASE_BACKUP_DIR="${XDG_DATA_HOME}/devbase/backup"
  export DEVBASE_REGISTRY_HOST='' DEVBASE_PYPI_REGISTRY='' DEVBASE_PROXY_HOST=''
  unset DEVBASE_APT_REGISTRY DEVBASE_GITHUB_REGISTRY DEVBASE_MISE_URL_REPLACEMENTS
  unset DEVBASE_MISE_PYTHON_COMPILE
  unset DEVBASE_GO_REGISTRY DEVBASE_GO_SUMDB DEVBASE_RUSTUP_DIST_SERVER DEVBASE_RUSTUP_UPDATE_ROOT
  unset DEVBASE_NPM_REGISTRY DEVBASE_CYPRESS_REGISTRY DEVBASE_CARGO_REGISTRY DEVBASE_RUBYGEMS_REGISTRY
  unset CARGO_HOME BUNDLE_CONFIG BUNDLE_USER_HOME BUNDLE_USER_CONFIG
  source "${DEVBASE_LIBS}/bootstrap/bootstrap-apply.sh"
  source "${DEVBASE_LIBS}/handle-network.sh"
  source "${DEVBASE_LIBS}/pkg/pkg-apt.sh"
  source "${DEVBASE_LIBS}/parse-packages.sh"
  source "${DEVBASE_LIBS}/utils.sh"
  source "${DEVBASE_LIBS}/process-templates.sh"
  get_mise_packages() { printf 'node|24.21.0\nrust|1.98.1\n'; }
  # Only fixture paths are passed to the APT configuration helper in this suite.
  sudo() { "$@"; }
  curl() { printf '%s\n' "$@"; }
  wget() { printf '%s\n' "$@"; }
}

teardown() {
  common_teardown
}

@test "a base registry URL alone leaves mise, APT and downloads on upstream" {
  export DEVBASE_REGISTRY_URL='https://registry.example'
  export MISE_URL_REPLACEMENTS='{"https://personal.example/":"https://personal-mirror.example/"}'
  apply_environment_settings
  assert_equal "$MISE_URL_REPLACEMENTS" '{"https://personal.example/":"https://personal-mirror.example/"}'
  generate_mise_config "$TEST_DIR/mise.toml"
  assert_equal "$(yq -p=toml '.settings.url_replacements' "$TEST_DIR/mise.toml")" null
  assert_equal "$(yq -p=toml '.tools.rust' "$TEST_DIR/mise.toml")" 1.98.1
  assert_equal "$(yq -p=toml '.settings.python.compile' "$TEST_DIR/mise.toml")" null
  assert_equal "$(yq -p=toml '.settings.paranoid' "$TEST_DIR/mise.toml")" true
  mkdir -p "$TEST_DIR/apt"
  printf 'deb https://archive.ubuntu.com/ubuntu resolute main\n' >"$TEST_DIR/apt/sources.list"
  _pkg_apt_configure_mirror "$TEST_DIR/apt"
  assert_file_not_exists "$TEST_DIR/apt/sources.list.devbase-backup"
  assert_dir_not_exists "$DEVBASE_BACKUP_DIR/apt"
  run devbase_curl -fL 'https://github.com/jdx/mise/releases/download/v1/mise.tar.gz'
  assert_line 'https://github.com/jdx/mise/releases/download/v1/mise.tar.gz'
  run mise_uses_github_api_mirror
  assert_failure
}

@test "APT and direct release mirrors remain independent of mise routing and client authentication" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu'
  export DEVBASE_GITHUB_REGISTRY='https://registry.example/github'
  export DEVBASE_MISE_URL_REPLACEMENTS=''
  export MISE_GITHUB_TOKEN='test-client-token'
  unset MISE_URL_REPLACEMENTS
  apply_environment_settings
  [[ ! -v MISE_URL_REPLACEMENTS ]]
  generate_mise_config "$TEST_DIR/mise.toml"
  assert_equal "$(yq -p=toml '.settings.url_replacements' "$TEST_DIR/mise.toml")" null
  assert_equal "$(yq -p=toml '.tools.rust' "$TEST_DIR/mise.toml")" 1.98.1
  assert_equal "$(yq -p=toml '.settings.paranoid' "$TEST_DIR/mise.toml")" true
  run mise_uses_github_api_mirror
  assert_failure
  run check_mise_github_token
  assert_success
  assert_output --partial 'GitHub token (MISE_GITHUB_TOKEN) configured'
  run devbase_curl -fL 'https://github.com/jdx/mise/releases/download/v1/mise.tar.gz'
  assert_line 'https://registry.example/github/jdx/mise/releases/download/v1/mise.tar.gz'
  mkdir -p "$TEST_DIR/apt"
  printf 'deb https://archive.ubuntu.com/ubuntu resolute main\n' >"$TEST_DIR/apt/sources.list"
  _pkg_apt_configure_mirror "$TEST_DIR/apt"
  assert_equal "$(cat "$TEST_DIR/apt/sources.list")" 'deb https://registry.example/ubuntu/ resolute main'
}

@test "one org map reaches no-config bootstrap and native global mise settings" {
  export DEVBASE_MISE_URL_REPLACEMENTS='{"https://api.github.com/":"https://registry.example/api/","https://github.com/":"https://registry.example/releases/"}'
  export DEVBASE_RUSTUP_DIST_SERVER='https://registry.example/rust'
  export DEVBASE_RUSTUP_UPDATE_ROOT='https://registry.example/rust/rustup'
  export DEVBASE_MISE_PYTHON_COMPILE=false
  export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise" MISE_DATA_DIR="$XDG_DATA_HOME/mise"
  export MISE_CACHE_DIR="$TEST_DIR/cache" MISE_STATE_DIR="$TEST_DIR/state" MISE_SYSTEM_CONFIG_DIR="$TEST_DIR/system"
  export MISE_OFFLINE=true
  unset MISE_GLOBAL_CONFIG_FILE
  apply_environment_settings
  assert_equal "$MISE_URL_REPLACEMENTS" "$DEVBASE_MISE_URL_REPLACEMENTS"
  assert_equal "$RUSTUP_DIST_SERVER" "$DEVBASE_RUSTUP_DIST_SERVER"
  assert_equal "$MISE_USE_VERSIONS_HOST_TRACK" false
  assert_equal "$MISE_PYTHON_COMPILE" false
  local mise_bin="${DEVBASE_TEST_MISE_BIN:-}"
  if [[ -x "$mise_bin" ]]; then
    run "$mise_bin" --no-config settings get use_versions_host_track
    assert_success
    assert_output false
  fi
  mkdir -p "$MISE_CONFIG_DIR"
  generate_mise_config "$MISE_CONFIG_DIR/config.toml"
  assert_equal "$(yq -p=toml '.settings.paranoid' "$MISE_CONFIG_DIR/config.toml")" true
  assert_equal "$(yq -p=toml '.settings.python.compile' "$MISE_CONFIG_DIR/config.toml")" false
  assert_equal "$(yq -p=toml '.tools.rust.install_env.RUSTUP_DIST_SERVER' "$MISE_CONFIG_DIR/config.toml")" "$DEVBASE_RUSTUP_DIST_SERVER"
  unset MISE_URL_REPLACEMENTS MISE_USE_VERSIONS_HOST_TRACK MISE_PYTHON_COMPILE
  if [[ -x "$mise_bin" ]]; then
    run "$mise_bin" --cd "$HOME" settings get use_versions_host_track
    assert_success
    assert_output false
    run "$mise_bin" --cd "$HOME" settings get paranoid
    assert_success
    assert_output true
    run "$mise_bin" --cd "$HOME" settings get python.compile
    assert_success
    assert_output false
  fi
}

@test "Rust mirrors do not add an unselected Rust tool" {
  export DEVBASE_RUSTUP_DIST_SERVER='https://registry.example/rust'
  export DEVBASE_RUSTUP_UPDATE_ROOT='https://registry.example/rust/rustup'
  get_mise_packages() { printf 'node|24.21.0\n'; }
  generate_mise_config "$TEST_DIR/mise.toml"
  assert_equal "$(yq -p=toml '.tools | keys | length' "$TEST_DIR/mise.toml")" 1
  assert_equal "$(yq -p=toml '.tools.node' "$TEST_DIR/mise.toml")" 24.21.0
  get_mise_packages() { printf 'core:rust|1.98.1\n'; }
  generate_mise_config "$TEST_DIR/mise.toml"
  assert_equal "$(yq -p=toml '.tools."core:rust".install_env.RUSTUP_DIST_SERVER' "$TEST_DIR/mise.toml")" "$DEVBASE_RUSTUP_DIST_SERVER"
}

@test "mise rejects malformed routing maps" {
  export DEVBASE_MISE_URL_REPLACEMENTS='{"https://github.com/":42}'
  run generate_mise_config "$TEST_DIR/mise.toml"
  assert_failure
}

@test "only a GitHub API mirror suppresses the client token prompt" {
  export MISE_GITHUB_TOKEN='' NON_INTERACTIVE=false
  ask_yes_no() { return 1; }
  export DEVBASE_MISE_URL_REPLACEMENTS='{"https://github.com/":"https://registry.example/releases/"}'
  run mise_uses_github_api_mirror
  assert_failure
  export DEVBASE_MISE_URL_REPLACEMENTS='{"https://api.github.com/":"https://api.github.com/"}'
  run mise_uses_github_api_mirror
  assert_failure
  export DEVBASE_MISE_URL_REPLACEMENTS='{"https://api.github.com/":"https://registry.example/api/"}'
  run check_mise_github_token
  assert_success
  assert_output --partial 'no client token required'
}

@test "release artifacts and checksums use the mirror through curl and wget" {
  export DEVBASE_GITHUB_REGISTRY='https://registry.example/github/'
  local client filename
  for client in devbase_curl devbase_wget; do
    for filename in mise.tar.gz SHASUMS256.txt; do
      run "$client" "https://github.com/jdx/mise/releases/download/v1/$filename"
      assert_success
      assert_output "https://registry.example/github/jdx/mise/releases/download/v1/$filename"
    done
    run "$client" 'https://github.com.example.org/jdx/mise/releases/download/v1/file'
    assert_output 'https://github.com.example.org/jdx/mise/releases/download/v1/file'
    run "$client" 'https://api.github.com/repos/jdx/mise/releases'
    assert_output 'https://api.github.com/repos/jdx/mise/releases'
  done
}

@test "GitHub mirrors require HTTPS before invoking either download client" {
  curl() { touch "$TEST_DIR/client-invoked"; }
  wget() { touch "$TEST_DIR/client-invoked"; }
  local mirror client
  for mirror in 'http://registry.example/github' 'file:///tmp/github'; do
    export DEVBASE_GITHUB_REGISTRY="$mirror"
    for client in devbase_curl devbase_wget; do
      run "$client" 'https://github.com/jdx/mise/releases/download/v1/SHASUMS256.txt'
      assert_failure
      assert_output --partial 'DEVBASE_GITHUB_REGISTRY must be an HTTPS repository URL'
      assert_file_not_exists "$TEST_DIR/client-invoked"
    done
  done
}

@test "early Gum bootstrap uses the optional GitHub mirror" {
  source "${DEVBASE_LIBS}/bootstrap/bootstrap-ui.sh"
  export NON_INTERACTIVE=false _DEVBASE_ENV=ubuntu DEVBASE_DEB_CACHE=''
  get_deb_arch() { printf 'amd64\n'; }
  command() {
    [[ "$*" == '-v gum' ]] && return 1
    builtin command "$@"
  }
  # Stop at download: no package installation or system changes in this test.
  curl() {
    printf '%s\n' "$@" >"$TEST_DIR/gum-request"
    return 1
  }
  local mirror expected
  for mirror in '' 'https://registry.example/github'; do
    export DEVBASE_GITHUB_REGISTRY="$mirror"
    expected="${mirror:-https://github.com}/charmbracelet/gum/releases/download/v2.0.1/gum_2.0.1_amd64.deb"
    run bootstrap_gum
    assert_failure
    run cat "$TEST_DIR/gum-request"
    assert_success
    assert_line "$expected"
  done
}

@test "APT preserves suites, signatures and third-party sources and is idempotent" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu'
  local apt_dir="$TEST_DIR/apt"
  mkdir -p "$apt_dir/sources.list.d"
  cat >"$apt_dir/sources.list.d/ubuntu.sources" <<'EOF'
Types: deb deb-src
URIs: http://se.archive.ubuntu.com/ubuntu/
 https://security.ubuntu.com/ubuntu
# https://archive.ubuntu.com/ubuntu is the original archive
Suites: resolute resolute-updates resolute-security
Components: main universe
Architectures: amd64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
  printf 'deb [signed-by=/keys/ubuntu.gpg] http://archive.ubuntu.com/ubuntu resolute main\n' >"$apt_dir/sources.list"
  # No final newline: untouched third-party files must be byte-identical.
  printf 'deb https://packages.mozilla.org/apt mozilla main' >"$apt_dir/sources.list.d/mozilla.list"
  _pkg_apt_configure_mirror "$apt_dir"
  assert_file_exists "$DEVBASE_BACKUP_DIR/apt/sources.list"
  assert_file_exists "$DEVBASE_BACKUP_DIR/apt/sources.list.d/ubuntu.sources"
  assert_file_not_exists "$apt_dir/sources.list.d/ubuntu.sources.devbase-backup"
  assert_equal "$(grep -c 'registry.example/ubuntu/' "$apt_dir/sources.list.d/ubuntu.sources")" 2
  run cat "$apt_dir/sources.list.d/ubuntu.sources"
  assert_line 'Suites: resolute resolute-updates resolute-security'
  assert_line 'Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg'
  assert_line '# https://archive.ubuntu.com/ubuntu is the original archive'
  assert_equal "$(cat "$apt_dir/sources.list")" 'deb [signed-by=/keys/ubuntu.gpg] https://registry.example/ubuntu/ resolute main'
  assert_file_not_exists "$DEVBASE_BACKUP_DIR/apt/sources.list.d/mozilla.list"
  local before
  before=$(sha256sum "$apt_dir/sources.list.d/ubuntu.sources" "$DEVBASE_BACKUP_DIR/apt/sources.list")
  _pkg_apt_configure_mirror "$apt_dir"
  assert_equal "$(sha256sum "$apt_dir/sources.list.d/ubuntu.sources" "$DEVBASE_BACKUP_DIR/apt/sources.list")" "$before"
}

@test "APT migrates old backups on mirrored sources and preserves existing backups" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu'
  local apt_dir="$TEST_DIR/apt" backup_dir="$DEVBASE_BACKUP_DIR/apt" file before backup_path
  mkdir -p "$apt_dir/sources.list.d"
  mkdir -p "$backup_dir/sources.list.d"
  for file in "$apt_dir/sources.list" "$apt_dir/sources.list.d/ubuntu.list" "$apt_dir/sources.list.d/ubuntu.sources"; do
    printf '# Already mirrored\n' >"$file"
    printf '# Original source\n' >"${file}.devbase-backup"
    printf '# Existing backup\n' >"${backup_dir}/${file#"$apt_dir"/}"
  done
  before=$(sha256sum "$apt_dir/sources.list" "$apt_dir/sources.list.d/ubuntu.list" "$apt_dir/sources.list.d/ubuntu.sources")
  _pkg_apt_configure_mirror "$apt_dir"
  _pkg_apt_configure_mirror "$apt_dir"
  assert_equal "$(sha256sum "$apt_dir/sources.list" "$apt_dir/sources.list.d/ubuntu.list" "$apt_dir/sources.list.d/ubuntu.sources")" "$before"
  for file in "$apt_dir/sources.list" "$apt_dir/sources.list.d/ubuntu.list" "$apt_dir/sources.list.d/ubuntu.sources"; do
    backup_path="${backup_dir}/${file#"$apt_dir"/}"
    assert_file_not_exists "${file}.devbase-backup"
    assert_equal "$(cat "$backup_path")" '# Original source'
    assert_equal "$(cat "${backup_path}.~1~")" '# Existing backup'
    assert_file_not_exists "${backup_path}.~2~"
  done
  if command -v apt-get >/dev/null; then
    # Read only fixture sources: no network access or package installation.
    run apt-get -o "Dir::Etc=$apt_dir" -o "Dir::State::lists=$TEST_DIR/lists" indextargets
    assert_success
    refute_output --partial 'devbase-backup'
  fi
}

@test "APT limits replacements to archive URI fields and treats mirror paths literally" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu&archive'
  local apt_dir="$TEST_DIR/apt"
  mkdir -p "$apt_dir/sources.list.d"
  cat >"$apt_dir/sources.list.d/ubuntu.sources" <<'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu https://security.ubuntu.com/ubuntu/
 https://se.archive.ubuntu.com/ubuntu
 # https://security.ubuntu.com/ubuntu is a comment
X-Documentation: https://archive.ubuntu.com/ubuntu
 https://archive.ubuntu.com/ubuntu/
Suites: resolute

Types: deb-src
URIs: https://archive.ubuntu.com/ubuntu-extra https://archive.ubuntu.com.example/ubuntu
Suites: resolute

Types: deb
URIs: https://security.ubuntu.com/ubuntu
Suites: resolute-security
EOF
  printf 'deb-src https://archive.ubuntu.com/ubuntu resolute main' >"$apt_dir/sources.list"
  printf 'deb-src https://registry.example/ubuntu&archive/ resolute main' >"$TEST_DIR/expected.list"

  run _pkg_apt_configure_mirror "$apt_dir"
  assert_success

  assert_files_equal "$TEST_DIR/expected.list" "$apt_dir/sources.list"
  run cat "$apt_dir/sources.list.d/ubuntu.sources"
  assert_line 'URIs: https://registry.example/ubuntu&archive/ https://registry.example/ubuntu&archive/'
  assert_line ' https://registry.example/ubuntu&archive/'
  assert_line ' # https://security.ubuntu.com/ubuntu is a comment'
  assert_line 'X-Documentation: https://archive.ubuntu.com/ubuntu'
  assert_line ' https://archive.ubuntu.com/ubuntu/'
  assert_line 'URIs: https://archive.ubuntu.com/ubuntu-extra https://archive.ubuntu.com.example/ubuntu'
  assert_line 'URIs: https://registry.example/ubuntu&archive/'
}

@test "APT leaves sources and adjacent backups intact if backup copying fails" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu'
  local apt_dir="$TEST_DIR/apt"
  mkdir -p "$apt_dir/sources.list.d"
  printf 'deb https://archive.ubuntu.com/ubuntu resolute main\n' >"$apt_dir/sources.list"
  printf '# Original source\n' >"$apt_dir/sources.list.devbase-backup"
  cp() { return 1; }
  run _pkg_apt_configure_mirror "$apt_dir"
  assert_failure
  assert_file_exists "$apt_dir/sources.list.devbase-backup"
  assert_equal "$(cat "$apt_dir/sources.list")" 'deb https://archive.ubuntu.com/ubuntu resolute main'
  rm "$apt_dir/sources.list.devbase-backup"
  run _pkg_apt_configure_mirror "$apt_dir"
  assert_failure
  assert_equal "$(cat "$apt_dir/sources.list")" 'deb https://archive.ubuntu.com/ubuntu resolute main'
}

@test "APT rejects an invalid mirror before changing sources" {
  export DEVBASE_APT_REGISTRY='http://registry.example/ubuntu'
  run _pkg_apt_configure_mirror "$TEST_DIR/apt"
  assert_failure
  assert_output --partial 'HTTPS repository URL'
}

@test "APT rejects linked and non-regular backups before changing sources" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu'
  local apt_dir="$TEST_DIR/apt" backup="$DEVBASE_BACKUP_DIR/apt/sources.list"
  mkdir -p "$apt_dir" "$DEVBASE_BACKUP_DIR/apt"
  printf 'deb https://archive.ubuntu.com/ubuntu resolute main\n' >"$apt_dir/sources.list"
  cp "$apt_dir/sources.list" "$TEST_DIR/previous.list"
  ln -s "$TEST_DIR/missing-backup" "$backup"

  run _pkg_apt_configure_mirror "$apt_dir"
  assert_failure
  assert_output --partial 'Refusing invalid APT backup'
  assert_files_equal "$TEST_DIR/previous.list" "$apt_dir/sources.list"
  assert_symlink_to "$TEST_DIR/missing-backup" "$backup"
  assert_file_not_exists "$TEST_DIR/missing-backup"

  rm "$backup"
  mkdir "$backup"
  run _pkg_apt_configure_mirror "$apt_dir"
  assert_failure
  assert_output --partial 'Refusing invalid APT backup'
  assert_files_equal "$TEST_DIR/previous.list" "$apt_dir/sources.list"
  assert_dir_exists "$backup"
}

@test "APT preserves active sources and cleans staging after a real write failure" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu'
  local apt_dir="$TEST_DIR/apt"
  mkdir -p "$apt_dir"
  printf 'deb https://archive.ubuntu.com/ubuntu resolute main\n' >"$apt_dir/sources.list"
  cp "$apt_dir/sources.list" "$TEST_DIR/previous.list"
  sudo() {
    if [[ "$1" == install ]]; then
      # Fail the real copy after backup succeeds, using an OS file-size limit.
      (trap '' XFSZ; ulimit -f 0; "$@")
    else
      "$@"
    fi
  }

  run _pkg_apt_configure_mirror "$apt_dir"
  assert_failure
  assert_files_equal "$TEST_DIR/previous.list" "$apt_dir/sources.list"
  assert_files_equal "$TEST_DIR/previous.list" "$DEVBASE_BACKUP_DIR/apt/sources.list"
  run find "$apt_dir" -name '.devbase-apt.*'
  assert_output ''
}

@test "APT preserves active sources and cleans staging when publication fails" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu'
  local apt_dir="$TEST_DIR/apt"
  mkdir -p "$apt_dir"
  printf 'deb https://archive.ubuntu.com/ubuntu resolute main\n' >"$apt_dir/sources.list"
  cp "$apt_dir/sources.list" "$TEST_DIR/previous.list"
  sudo() {
    [[ "$1" != mv ]] || return 1
    "$@"
  }

  run _pkg_apt_configure_mirror "$apt_dir"
  assert_failure
  assert_files_equal "$TEST_DIR/previous.list" "$apt_dir/sources.list"
  assert_files_equal "$TEST_DIR/previous.list" "$DEVBASE_BACKUP_DIR/apt/sources.list"
  run find "$apt_dir" -name '.devbase-apt.*'
  assert_output ''
}

@test "APT interrupted backup cannot be mistaken for a complete backup on retry" {
  export DEVBASE_APT_REGISTRY='https://registry.example/ubuntu'
  local apt_dir="$TEST_DIR/apt"
  mkdir -p "$apt_dir"
  printf 'deb https://archive.ubuntu.com/ubuntu resolute main\n' >"$apt_dir/sources.list"
  cp "$apt_dir/sources.list" "$TEST_DIR/previous.list"
  cp() {
    local destination="${*: -1}"
    printf '# partial\n' >"$destination"
    return 1
  }
  run _pkg_apt_configure_mirror "$apt_dir"
  assert_failure
  assert_files_equal "$TEST_DIR/previous.list" "$apt_dir/sources.list"
  assert_file_not_exists "$DEVBASE_BACKUP_DIR/apt/sources.list"
  unset -f cp
  run _pkg_apt_configure_mirror "$apt_dir"
  assert_success
  assert_files_equal "$TEST_DIR/previous.list" "$DEVBASE_BACKUP_DIR/apt/sources.list"
  assert_equal "$(cat "$apt_dir/sources.list")" 'deb https://registry.example/ubuntu/ resolute main'
}

@test "Go and rustup native values persist through the existing Fish generator" {
  command -v fish >/dev/null || skip 'fish required'
  export DEVBASE_GO_REGISTRY='https://registry.example/go'
  export DEVBASE_GO_SUMDB='sum.golang.org https://registry.example/sum'
  export DEVBASE_RUSTUP_DIST_SERVER='https://registry.example/rust'
  export DEVBASE_RUSTUP_UPDATE_ROOT='https://registry.example/rust/rustup'
  apply_environment_settings
  assert_equal "$GOSUMDB" "$DEVBASE_GO_SUMDB"
  generate_fish_registry_config "$TEST_DIR/registry.fish"
  run fish --no-config -c 'source $argv[1]; printf "%s\n" $GOPROXY $GOSUMDB $RUSTUP_DIST_SERVER $RUSTUP_UPDATE_ROOT' "$TEST_DIR/registry.fish"
  assert_success
  assert_line "$DEVBASE_GO_REGISTRY"
  assert_line "$DEVBASE_GO_SUMDB"
  assert_line "$DEVBASE_RUSTUP_DIST_SERVER"
  assert_line "$DEVBASE_RUSTUP_UPDATE_ROOT"
}

@test "Cypress binary mirror reaches install-time and persistent client configuration independently of mise" {
  command -v fish >/dev/null || skip 'fish required'
  export DEVBASE_CYPRESS_REGISTRY='https://registry.example/repository/cypress-binaries-proxy'
  export DEVBASE_MISE_URL_REPLACEMENTS=''
  unset MISE_URL_REPLACEMENTS
  apply_environment_settings
  assert_equal "$CYPRESS_DOWNLOAD_MIRROR" "$DEVBASE_CYPRESS_REGISTRY"
  [[ ! -v MISE_URL_REPLACEMENTS ]]
  generate_fish_registry_config "$TEST_DIR/registry.fish"
  run fish --no-config -c 'source $argv[1]; printf "%s\n" $CYPRESS_DOWNLOAD_MIRROR' "$TEST_DIR/registry.fish"
  assert_success
  assert_output "$DEVBASE_CYPRESS_REGISTRY"
}

@test "Cargo and Bundler templates are opt-in and preserve existing user files" {
  printf 'registry = "${DEVBASE_CARGO_REGISTRY}"\n' >"$TEST_DIR/cargo-config.toml.template"
  printf 'mirror: "${DEVBASE_RUBYGEMS_REGISTRY}"\n' >"$TEST_DIR/bundle-config.template"
  process_template_file "$TEST_DIR/cargo-config.toml.template" cargo-config.toml.template
  process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_file_not_exists "$HOME/.cargo/config.toml"
  assert_file_not_exists "$HOME/.bundle/config"
  # org.env is sourced, so ordinary assignments must work without export.
  DEVBASE_CARGO_REGISTRY='https://registry.example/cargo'
  DEVBASE_RUBYGEMS_REGISTRY='https://registry.example/gems'
  process_template_file "$TEST_DIR/cargo-config.toml.template" cargo-config.toml.template
  process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_equal "$(cat "$HOME/.cargo/config.toml")" 'registry = "https://registry.example/cargo"'
  assert_equal "$(cat "$HOME/.bundle/config")" 'mirror: "https://registry.example/gems"'
  printf '# personal Cargo config\n' >"$HOME/.cargo/config.toml"
  printf '# personal Bundler config\n' >"$HOME/.bundle/config"
  process_template_file "$TEST_DIR/cargo-config.toml.template" cargo-config.toml.template
  process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_equal "$(cat "$HOME/.cargo/config.toml")" '# personal Cargo config'
  assert_equal "$(cat "$HOME/.bundle/config")" '# personal Bundler config'
}

_setup_native_registry_templates() {
  DEVBASE_CARGO_REGISTRY='https://registry.example/cargo'
  DEVBASE_RUBYGEMS_REGISTRY='https://registry.example/gems'
  printf 'registry = "${DEVBASE_CARGO_REGISTRY}"\n' >"$TEST_DIR/cargo-config.toml.template"
  printf 'mirror: "${DEVBASE_RUBYGEMS_REGISTRY}"\n' >"$TEST_DIR/bundle-config.template"
}

@test "Cargo preserves legacy config precedence in default and custom homes" {
  _setup_native_registry_templates
  local home
  for home in "$HOME/.cargo" "$TEST_DIR/custom cargo"; do
    export CARGO_HOME="$home"
    mkdir -p "$home"
    printf '# personal legacy config without final newline' >"$home/config"
    chmod 640 "$home/config"
    run process_template_file "$TEST_DIR/cargo-config.toml.template" cargo-config.toml.template
    assert_success
    assert_output --partial "Preserving existing Cargo config: $home/config"
    assert_output --partial 'apply registry changes manually'
    assert_file_not_exists "$home/config.toml"
    assert_equal "$(cat "$home/config")" '# personal legacy config without final newline'
    assert_equal "$(stat -c %a "$home/config")" 640
    printf '# personal modern config\n' >"$home/config.toml"
    run process_template_file "$TEST_DIR/cargo-config.toml.template" cargo-config.toml.template
    assert_success
    assert_equal "$(cat "$home/config")" '# personal legacy config without final newline'
    assert_equal "$(cat "$home/config.toml")" '# personal modern config'
  done
}

@test "Cargo preserves legacy symlinks including dangling links" {
  _setup_native_registry_templates
  mkdir -p "$HOME/.cargo"
  printf '# personal linked config\n' >"$TEST_DIR/linked-config"
  local destination
  for destination in "$TEST_DIR/linked-config" "$TEST_DIR/missing-config"; do
    ln -s "$destination" "$HOME/.cargo/config"
    run process_template_file "$TEST_DIR/cargo-config.toml.template" cargo-config.toml.template
    assert_success
    assert_symlink_to "$destination" "$HOME/.cargo/config"
    assert_file_not_exists "$HOME/.cargo/config.toml"
    rm "$HOME/.cargo/config"
  done
  assert_equal "$(cat "$TEST_DIR/linked-config")" '# personal linked config'
  assert_file_not_exists "$TEST_DIR/missing-config"
}

@test "Cargo and Bundler seed their configured homes without writing default locations" {
  _setup_native_registry_templates
  export CARGO_HOME="$TEST_DIR/cargo home" BUNDLE_USER_HOME="$TEST_DIR/bundle home"
  run process_template_file "$TEST_DIR/cargo-config.toml.template" cargo-config.toml.template
  assert_success
  run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_success
  assert_equal "$(cat "$CARGO_HOME/config.toml")" 'registry = "https://registry.example/cargo"'
  assert_equal "$(cat "$BUNDLE_USER_HOME/config")" 'mirror: "https://registry.example/gems"'
  assert_file_not_exists "$CARGO_HOME/config"
  assert_dir_not_exists "$HOME/.cargo"
  assert_dir_not_exists "$HOME/.bundle"
}

@test "Bundler explicit config takes precedence over its home and preserves personal edits" {
  _setup_native_registry_templates
  export BUNDLE_CONFIG=''
  export BUNDLE_USER_HOME="$TEST_DIR/bundle home" BUNDLE_USER_CONFIG="$TEST_DIR/explicit config/settings"
  run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_success
  assert_equal "$(cat "$BUNDLE_USER_CONFIG")" 'mirror: "https://registry.example/gems"'
  assert_equal "$(stat -c %a "$BUNDLE_USER_CONFIG")" 600
  printf '# personal Bundler settings\n' >"$BUNDLE_USER_CONFIG"
  run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_success
  assert_output --partial "Preserving existing Bundler config: $BUNDLE_USER_CONFIG"
  assert_equal "$(cat "$BUNDLE_USER_CONFIG")" '# personal Bundler settings'
  : >"$BUNDLE_USER_CONFIG"
  run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_success
  assert [ ! -s "$BUNDLE_USER_CONFIG" ]
  assert_dir_not_exists "$BUNDLE_USER_HOME"
  assert_dir_not_exists "$HOME/.bundle"
}

@test "Bundler BUNDLE_CONFIG takes precedence and preserves existing files and links" {
  _setup_native_registry_templates
  export BUNDLE_CONFIG="$TEST_DIR/active config" BUNDLE_USER_CONFIG="$TEST_DIR/unused config"
  export BUNDLE_USER_HOME="$TEST_DIR/bundle home"
  run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_success
  assert_equal "$(cat "$BUNDLE_CONFIG")" 'mirror: "https://registry.example/gems"'
  assert_equal "$(stat -c %a "$BUNDLE_CONFIG")" 600
  printf '# personal Bundler settings\n' >"$BUNDLE_CONFIG"
  run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_success
  assert_output --partial "Preserving existing Bundler config: $BUNDLE_CONFIG"
  assert_equal "$(cat "$BUNDLE_CONFIG")" '# personal Bundler settings'
  rm "$BUNDLE_CONFIG"
  printf '# linked settings\n' >"$TEST_DIR/linked-config"
  local destination
  for destination in "$TEST_DIR/linked-config" "$TEST_DIR/missing-config"; do
    ln -s "$destination" "$BUNDLE_CONFIG"
    run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
    assert_success
    assert_symlink_to "$destination" "$BUNDLE_CONFIG"
    rm "$BUNDLE_CONFIG"
  done
  assert_equal "$(cat "$TEST_DIR/linked-config")" '# linked settings'
  assert_file_not_exists "$TEST_DIR/missing-config"
  assert_file_not_exists "$BUNDLE_USER_CONFIG"
  assert_dir_not_exists "$BUNDLE_USER_HOME"
  assert_dir_not_exists "$HOME/.bundle"
}

@test "Bundler preserves an explicit config symlink without falling back to its home" {
  _setup_native_registry_templates
  export BUNDLE_USER_HOME="$TEST_DIR/bundle home" BUNDLE_USER_CONFIG="$TEST_DIR/bundler-settings"
  printf '# personal linked settings\n' >"$TEST_DIR/linked-config"
  local destination
  for destination in "$TEST_DIR/linked-config" "$TEST_DIR/missing-config"; do
    ln -s "$destination" "$BUNDLE_USER_CONFIG"
    run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
    assert_success
    assert_symlink_to "$destination" "$BUNDLE_USER_CONFIG"
    rm "$BUNDLE_USER_CONFIG"
  done
  assert_equal "$(cat "$TEST_DIR/linked-config")" '# personal linked settings'
  assert_file_not_exists "$TEST_DIR/missing-config"
  assert_dir_not_exists "$BUNDLE_USER_HOME"
  assert_dir_not_exists "$HOME/.bundle"
}

@test "Native registry config overrides remain opt-in" {
  _setup_native_registry_templates
  unset DEVBASE_CARGO_REGISTRY DEVBASE_RUBYGEMS_REGISTRY
  export CARGO_HOME="$TEST_DIR/cargo home" BUNDLE_USER_HOME="$TEST_DIR/bundle home" BUNDLE_USER_CONFIG="$TEST_DIR/bundle-settings" BUNDLE_CONFIG="$TEST_DIR/active-bundle-settings"
  run process_template_file "$TEST_DIR/cargo-config.toml.template" cargo-config.toml.template
  assert_success
  run process_template_file "$TEST_DIR/bundle-config.template" bundle-config.template
  assert_success
  assert_dir_not_exists "$CARGO_HOME"
  assert_dir_not_exists "$BUNDLE_USER_HOME"
  assert_file_not_exists "$BUNDLE_USER_CONFIG"
  assert_file_not_exists "$BUNDLE_CONFIG"
}
