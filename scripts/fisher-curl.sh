#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT

# Scoped to Devbase's Fisher subprocesses, never installed as the user's curl.
# Fisher fetches API tarballs itself; serve only our two version-pinned sources.
set -Eeuo pipefail

output='' url=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      output="$2"
      shift 2 ;;
    -w)
      [[ "$2" == '%{http_code}' ]] || exit 1
      shift 2 ;;
    -q | --silent | -L) shift ;;
    https://*)
      [[ -z "$url" ]] || exit 1
      url="$1"
      shift ;;
    *)
      printf 'Unsupported Fisher curl argument: %s\n' "$1" >&2
      exit 1 ;;
  esac
done
[[ -n "$output" && -n "$url" ]] || exit 1

case "$url" in
  "https://api.github.com/repos/jorgebucaran/fisher/tarball/${DEVBASE_FISHER_VERSION:?}")
    version="$DEVBASE_FISHER_VERSION"
    path="jorgebucaran/fisher/tar.gz/refs/tags/${DEVBASE_FISHER_VERSION}"
    ;;
  "https://api.github.com/repos/patrickf1/fzf.fish/tarball/${DEVBASE_FZF_FISH_VERSION:?}")
    version="$DEVBASE_FZF_FISH_VERSION"
    path="PatrickF1/fzf.fish/tar.gz/refs/tags/${DEVBASE_FZF_FISH_VERSION}"
    ;;
  *)
    printf 'Fisher archive is not configured for mirrored installation: %s\n' "$url" >&2
    exit 1 ;;
esac
mirror="${DEVBASE_GITHUB_CODELOAD_REGISTRY:?}"
[[ "$mirror" == https://* && "$version" =~ ^v?[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || {
  echo 'Fisher mirror requires HTTPS and an exact release version.' >&2
  exit 1
}

# Use the same source exceptions and strictness as the bootstrap downloader.
# shellcheck source=../libs/handle-network.sh
# shellcheck disable=SC1091 # Loaded from the runtime core directory.
source "${DEVBASE_ROOT:?}/libs/handle-network.sh"
if ! _checksum_allowlisted "https://codeload.github.com/${path}"; then
  case "$(_normalize_strict_mode "${DEVBASE_STRICT_CHECKSUMS:-fail}")" in
    fail)
      echo 'Checksum required for Fisher source: no matching source exception.' >&2
      exit 1 ;;
    warn) echo 'WARNING: No checksum configured for Fisher source.' >&2 ;;
  esac
fi

# No redirect following, credentials, disabled TLS verification or upstream fallback.
status="$("${DEVBASE_FISHER_CURL_BIN:?}" --disable -sS --connect-timeout 10 --max-time 90 \
  -o "$output" -w '%{http_code}' "${mirror%/}/${path}")"
if [[ "$status" != 200 ]]; then
  printf 'Fisher archive download failed (HTTP %s): %s\n' "$status" "$path" >&2
  exit 1
fi
if [[ ! -s "$output" ]]; then
  echo 'Fisher mirror returned an empty archive.' >&2
  exit 1
fi
printf 200
