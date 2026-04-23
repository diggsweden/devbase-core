#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Linting tests for renovate.json custom managers.
#
# Catches a class of silent failure: renovate applies `matchStrings`
# regexes in single-line mode by default, so `^` anchors the start of
# the whole file and `$` anchors the end. A regex that uses these
# anchors but forgets the `(?m)` inline flag will extract zero
# dependencies without raising any error — causing every pinned
# version in that file to silently go stale.
#
# See https://docs.renovatebot.com/configuration-options/#matchstrings

bats_require_minimum_version 1.13.0

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
  export DEVBASE_ROOT
}

# Helper: strip character classes `[...]` from a regex so `$`/`^` inside
# them are not misinterpreted as anchors by the lint.
_strip_char_classes() {
  # Remove bracketed groups non-greedily. Handles escaped `\]` inside.
  sed -E 's/\[([^]\\]|\\.)*\]//g'
}

@test "renovate.json parses as valid JSON" {
  run jq -e . "${DEVBASE_ROOT}/renovate.json"
  assert_success
}

@test "every customManagers matchString with ^/\$ anchors also declares (?m)" {
  local offenders=()
  local total=0
  local regex flags anchors

  while IFS= read -r regex; do
    total=$((total + 1))
    # Extract inline flag block at the start of the pattern, if any:
    # `(?m)`, `(?im)`, `(?s-i)` etc. Default to empty.
    flags=""
    if [[ "$regex" =~ ^\(\?([a-z-]+)\) ]]; then
      flags="${BASH_REMATCH[1]}"
    fi

    # Strip character classes so `[...$...]` does not flag as an anchor.
    anchors=$(printf '%s' "$regex" | _strip_char_classes)
    # Look for an unescaped `^` at start-of-pattern (after optional flags)
    # or an unescaped `$` anywhere outside a character class.
    local has_anchor=0
    if [[ "$anchors" =~ (^|[^\\])\^ ]] || [[ "$anchors" =~ (^|[^\\])\$ ]]; then
      has_anchor=1
    fi

    if (( has_anchor )) && [[ "$flags" != *m* ]]; then
      offenders+=("$regex")
    fi
  done < <(jq -r '.customManagers[]?.matchStrings[]?' "${DEVBASE_ROOT}/renovate.json")

  if (( ${#offenders[@]} > 0 )); then
    printf 'Renovate custom manager regexes use ^/$ without (?m).\n' >&2
    printf 'This causes renovate to extract zero deps (silent failure).\n' >&2
    printf 'Prefix the regex with (?m) to enable multi-line matching.\n\n' >&2
    for r in "${offenders[@]}"; do printf '  %s\n' "$r" >&2; done
    return 1
  fi

  [[ "$total" -gt 0 ]] || { echo "No matchStrings found — regex selector broken?" >&2; return 1; }
}

@test "every customManagers entry references a manager file that exists in the repo" {
  # managerFilePatterns can be glob or regex (regex is wrapped in /.../).
  # We only check regex-style patterns here since that is what this repo uses,
  # and we check that the literal filename segment is findable somewhere.
  local missing=()
  local pattern file_basename

  while IFS= read -r pattern; do
    # Strip leading/trailing slashes (the regex delimiters).
    pattern="${pattern#/}"
    pattern="${pattern%/}"
    # Pull the filename at the end of the pattern: everything after the last
    # unescaped `/`. Then unescape `\.` → `.`.
    file_basename="${pattern##*/}"
    file_basename="${file_basename%\$}"
    file_basename="${file_basename//\\./.}"

    if ! find "${DEVBASE_ROOT}" \
         -path "${DEVBASE_ROOT}/.git" -prune -o \
         -type f -name "$file_basename" -print | grep -q .; then
      missing+=("$pattern (looked for file named: $file_basename)")
    fi
  done < <(jq -r '.customManagers[]?.managerFilePatterns[]? | select(startswith("/") and endswith("/"))' "${DEVBASE_ROOT}/renovate.json")

  if (( ${#missing[@]} > 0 )); then
    printf 'Renovate customManagers reference files that do not exist:\n' >&2
    for m in "${missing[@]}"; do printf '  %s\n' "$m" >&2; done
    return 1
  fi
}
