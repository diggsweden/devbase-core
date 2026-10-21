#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT

# Publish the launcher before activating the mise configuration. Binary lookup
# happens at launch (without project config), so failed tool installs fail closed.
configure_opencode_launcher() (
  set -euo pipefail
  local packages opencode_version nono_version pack_version
  packages=$(get_mise_packages) || return 1
  opencode_version=$(awk -F'|' '$1 == "aqua:anomalyco/opencode" {print $2}' <<<"$packages")
  nono_version=$(awk -F'|' '$1 == "nono" {print $2}' <<<"$packages")
  local root="${XDG_DATA_HOME:-$HOME/.local/share}/devbase/opencode"
  local bin="${XDG_BIN_HOME:-$HOME/.local/bin}"
  if [[ -z "$opencode_version" ]]; then
    # Leave an existing managed launcher fail-closed when the pack is deselected.
    if [[ -f "$root/runtime.json" && ! -L "$root/runtime.json" ]] &&
      jq -e '.managed_by == "devbase"' "$root/runtime.json" >/dev/null; then
      rm -- "$root/runtime.json" || return 1
    fi
    return 0
  fi
  [[ -n "$nono_version" ]] || {
    show_progress error "OpenCode requires nono"
    return 1
  }
  pack_version=$(get_tool_version nono_opencode_pack) || return 1
  [[ "$pack_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    show_progress error "OpenCode requires a pinned nono_opencode_pack"
    return 1
  }
  # Do not reinterpret selectors as paths or allow automatic major migrations.
  [[ "$opencode_version" =~ ^v?1\.[0-9]+\.[0-9]+$ && "$nono_version" =~ ^v?0\.[0-9]+\.[0-9]+$ ]] || {
    show_progress error "OpenCode integration requires exact OpenCode 1.x and nono 0.x pins"
    return 1
  }
  local file
  for file in "$root" "$bin" "$root/launcher" "$root/runtime.json"; do
    [[ ! -L "$file" ]] || {
      show_progress error "Refusing linked OpenCode installation path: $file"
      return 1
    }
  done
  if [[ -e "$bin/opencode" || -L "$bin/opencode" ]]; then
    [[ -L "$bin/opencode" && $(readlink -- "$bin/opencode") == "$root/launcher" ]] || {
      show_progress error "Existing $bin/opencode must be moved before installing the sandbox launcher"
      return 1
    }
  fi
  if [[ -d "$root" ]] && [[ ! -f "$root/launcher" ]] && [[ -n $(ls -A "$root") ]]; then
    show_progress error "Refusing unmanaged OpenCode launcher directory: $root"
    return 1
  fi
  if [[ -f "$root/launcher" ]] && ! grep -Fxq '# Managed by DevBase: sandboxed OpenCode launcher' "$root/launcher"; then
    show_progress error "Refusing unmanaged OpenCode launcher: $root/launcher"
    return 1
  fi
  mkdir -p "$root" "$bin" || return 1
  local stage
  stage=$(mktemp -d "$root/.stage.XXXXXX") || return 1
  trap 'rm -rf -- "$stage"' EXIT
  cp -- "$DEVBASE_ROOT/devbase_files/opencode/launcher" "$stage/launcher" || return 1
  chmod 755 "$stage/launcher" || return 1
  local mise_binary mise_data
  mise_binary=$(realpath -e -- "$(command -v mise)") || return 1
  mise_data=$(realpath -m -- "${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}") || return 1
  jq -n --arg mise "$mise_binary" --arg data "$mise_data" \
    --arg opencode "aqua:anomalyco/opencode@$opencode_version" --arg nono "nono@$nono_version" --arg pack_version "$pack_version" \
    '{managed_by: "devbase", mise: $mise, mise_data: $data, opencode: $opencode, nono: $nono, pack_version: $pack_version}' >"$stage/runtime.json" || return 1
  for file in launcher runtime.json; do
    mv -T -- "$stage/$file" "$root/$file" || return 1
  done
  [[ -L "$bin/opencode" ]] || ln -s -- "$root/launcher" "$bin/opencode"
)

# nono verifies the signed pack and wires its plugin and skill. Never force over
# personal files or a conflicting v2 pack; installation must report the conflict.
install_nono_opencode_pack() (
  local version
  version=$(get_tool_version nono_opencode_pack) || return 1
  [[ -n "$version" ]] || return 0
  local runtime="${XDG_DATA_HOME:-$HOME/.local/share}/devbase/opencode/runtime.json"
  local mise_binary mise_data nono_ref nono_dir opencode_ref opencode_dir var
  mise_binary=$(jq -er '.mise' "$runtime") || return 1
  mise_data=$(jq -er '.mise_data' "$runtime") || return 1
  nono_ref=$(jq -er '.nono' "$runtime") || return 1
  opencode_ref=$(jq -er '.opencode' "$runtime") || return 1
  for var in ${!NONO_@} ${!MISE_@}; do unset "$var"; done
  export MISE_DATA_DIR="$mise_data"
  nono_dir=$("$mise_binary" --no-config where "$nono_ref") || return 1
  opencode_dir=$("$mise_binary" --no-config where "$opencode_ref") || return 1
  if [[ ! -x "$nono_dir/nono" || ! -x "$opencode_dir/opencode" ]]; then
    show_progress error "AI setup requires both pinned OpenCode and nono executables; check the mise installation log"
    return 1
  fi
  (
    cd "$HOME" || return 1
    "$nono_dir/nono" pull "nolabs-ai/opencode-v1@$version" --registry https://registry.nono.sh
  ) || return 1
  "$nono_dir/nono" pin nolabs-ai/opencode-v1 || return 1
  show_progress success "Installed nono OpenCode v1 pack ($version)"
)
