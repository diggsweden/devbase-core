#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Render docs/tools-matrix.adoc from dot/.config/devbase/packages.yaml.
# The manifest is the single source of truth: every entry carries a
# description and, where known, a license; `theme: true` marks tools that
# devbase-theme configures. Run through `just docs-tools-matrix`.

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
manifest="${repo_root}/dot/.config/devbase/packages.yaml"
output="${1:-${repo_root}/docs/tools-matrix.adoc}"

export FIELD_SEP=$'\x1f'

command -v yq >/dev/null || {
  echo "yq is required" >&2
  exit 1
}

# Brief: Print the upstream link for a manifest entry
# Params: $1 = kind (apt, dnf, snap, flatpak, mise, custom, vscode, common), $2 = name, $3 = backend
tool_url() {
  local kind="$1" name="$2" backend="$3"
  case "$backend" in
  aqua:*/*/*) printf 'https://github.com/%s' "$(cut -d: -f2 <<<"$backend" | cut -d/ -f1,2)" ;;
  aqua:* | github:*) printf 'https://github.com/%s' "${backend#*:}" ;;
  gitlab:*) printf 'https://gitlab.com/%s' "${backend#*:}" ;;
  forgejo:*) printf 'https://codeberg.org/%s' "${backend#*:}" ;;
  go:*) printf 'https://pkg.go.dev/%s' "${backend#*:}" ;;
  esac
  [[ -n "$backend" ]] && return 0
  case "$kind" in
  apt | common) printf 'https://packages.ubuntu.com/%s' "$name" ;;
  dnf) printf 'https://packages.fedoraproject.org/pkgs/%s/' "${name#@}" ;;
  snap) printf 'https://snapcraft.io/%s' "$name" ;;
  flatpak) printf 'https://flathub.org/apps/%s' "$name" ;;
  vscode) printf 'https://marketplace.visualstudio.com/items?itemName=%s' "$name" ;;
  mise) printf 'https://mise.jdx.dev/registry.html' ;;
  *) printf '' ;;
  esac
}

# Brief: Describe how a manifest entry is installed
install_method() {
  local kind="$1" backend="$2" installer="$3" options="$4"
  case "$kind" in
  common | apt | dnf) printf 'apt/dnf' ;;
  snap) [[ "$options" == *classic* ]] && printf 'snap/classic' || printf 'snap' ;;
  flatpak) printf 'flatpak' ;;
  vscode) printf 'vscode extension' ;;
  custom) printf 'installer (%s)' "$installer" ;;
  mise)
    case "$backend" in
    aqua:*) printf 'mise/aqua' ;;
    github:* | gitlab:* | forgejo:*) printf 'mise/%s' "${backend%%:*}" ;;
    go:* | cargo:* | npm:* | pipx:*) printf 'mise/%s' "${backend%%:*}" ;;
    *) printf 'mise/native' ;;
    esac
    ;;
  esac
}

# Brief: Emit one AsciiDoc table for a manifest section
# Params: $1 = yq path, $2 = kind
emit_rows() {
  local path="$1" kind="$2"
  yq -r "${path} // {} | to_entries[] | [.key, (.value.description // \"\"), (.value.license // \"\"), (.value.backend // \"\"), (.value.installer // \"\"), (.value.options // \"\"), ((.value.theme // false) | tostring), ((.value.tags // []) | join(\" \"))] | join(strenv(FIELD_SEP))" "$manifest" |
    # Tab is IFS whitespace and would collapse empty fields; the unit separator does not
    while IFS="$FIELD_SEP" read -r name description license backend installer options theme tags; do
      local url
      url=$(tool_url "$kind" "$name" "$backend")
      local shown="$name"
      [[ -n "$url" ]] && shown="link:${url}[${name}]"
      local notes=()
      [[ "$theme" == true ]] && notes+=("theme")
      [[ "$tags" == *@skip-wsl* ]] && notes+=("not on WSL")
      [[ "$tags" == *@optional* ]] && notes+=("optional")
      printf '|%s\n|%s\n|%s\n|%s\n|%s\n\n' "$shown" "$description" "$(install_method "$kind" "$backend" "$installer" "$options")" "${license:-}" "$(
        IFS=,
        printf '%s' "${notes[*]}"
      )"
    done
}

# Brief: Emit one titled AsciiDoc table for a manifest section
# Params: $1 = heading marker (=== or ====), $2 = title, $3 = yq path, $4 = kind
emit_section() {
  local marker="$1" title="$2" path="$3" kind="$4"
  local count
  count=$(yq -r "${path} // {} | length" "$manifest")
  [[ "$count" -gt 0 ]] || return 0
  printf '%s %s\n\n[cols="2,3,1,2,1", options="header"]\n|===\n|Tool |Description |Install |License |Notes\n\n' "$marker" "$title"
  emit_rows "$path" "$kind"
  printf '|===\n\n'
}

# Brief: Human label for a manifest kind
kind_label() {
  case "$1" in
  common) printf 'Distribution packages (all distros)' ;;
  apt) printf 'Distribution packages (Ubuntu/Debian)' ;;
  dnf) printf 'Distribution packages (Fedora)' ;;
  snap) printf 'Snap' ;;
  flatpak) printf 'Flatpak' ;;
  mise) printf 'mise tools' ;;
  custom) printf 'Custom installers' ;;
  vscode) printf 'VS Code extensions' ;;
  esac
}

{
  cat <<'HEADER'
// SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
//
// SPDX-License-Identifier: CC0-1.0

= DevBase Tools Matrix
:toc:
:toc-placement: macro

Every tool DevBase installs, generated from `dot/.config/devbase/packages.yaml`
by `just docs-tools-matrix`. Edit the manifest, not this file.

toc::[]

== Legend

* *Install*: `apt/dnf` distribution package (name differs per distro in the manifest), `snap`, `flatpak`,
  `mise/aqua` (checksum-verified GitHub releases through the aqua registry), `mise/github`, `mise/gitlab`,
  `mise/forgejo` (direct releases), `mise/go` (built with the Go toolchain), `mise/native` (mise core backend),
  `installer (...)` (DevBase installer function), `vscode extension`.
* Versions are not listed: Renovate keeps them current in `packages.yaml`, the single place to look them up.
* *Notes*: `theme` = configured by `devbase-theme`; `not on WSL` = skipped in WSL; `optional` = prompted or opt-in.
* Proxy support: every install method honours the proxy configured during setup; mise tools also honour
  mirror replacements from the custom configuration.

== Core (always installed)

HEADER
  for kind in common apt dnf snap flatpak mise custom vscode; do
    emit_section "===" "$(kind_label "$kind")" ".core.${kind}" "$kind"
  done

  printf '== Packs (selected during setup)\n\n'
  for pack in $(yq -r '.packs | keys | .[]' "$manifest"); do
    desc=$(yq -r ".packs.${pack}.description // \"\"" "$manifest")
    printf '=== %s %s\n\n' "$pack" "$desc"
    for kind in common apt dnf mise custom vscode; do
      emit_section "====" "$(kind_label "$kind")" ".packs.${pack}.${kind}" "$kind"
    done
  done

  cat <<'FOOTER'
== Not in the manifest

* `kubectl` is installed by the `oc` installer from the OpenShift mirror.
* `wl-clipboard`, `xclip` and `xsel` are installed for the detected display server.
* Fisher plugins (`fzf.fish`) are installed through Fisher, see the custom installers above.
FOOTER
} >"$output"

printf 'Wrote %s\n' "$output"
