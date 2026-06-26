#!/usr/bin/env bats

# shellcheck disable=SC1090,SC2016
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Linting tests for renovate.json custom managers and supply-chain age policy.
#
# Catches a class of silent failure: renovate applies `matchStrings`
# regexes in single-line mode by default, so `^` anchors the start of
# the whole file and `$` anchors the end. A regex that uses these
# anchors but forgets the `(?m)` inline flag will extract zero
# dependencies without raising any error — causing every pinned
# version in that file to silently go stale.
# See https://docs.renovatebot.com/configuration-options/#matchstrings
#
# Also guards the minimumReleaseAge supply-chain policy:
#   - Top-level default: 7 days (blocks newly-published packages)
#   - Datasources without timestamps (git-refs, custom.*) must override
#     minimumReleaseAge to null AND carry a schedule as the compensating
#     control. Without the null override, Renovate 42+ would block those
#     updates entirely (timestamp-required behaviour).
#
# See https://docs.renovatebot.com/key-concepts/minimum-release-age/

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

@test "top-level minimumReleaseAge is set to 7 days" {
  run jq -e '.minimumReleaseAge == "7 days"' "${DEVBASE_ROOT}/renovate.json"
  assert_success
}

@test "git-refs datasource is not used (lazyvim migrated to github-releases)" {
  # LazyVim/starter has no release tags, so git-refs provided no timestamps
  # and minimumReleaseAge could not be enforced. The entry was migrated to
  # track LazyVim/LazyVim github-releases instead.
  run jq -e '
    [.packageRules[]? | .matchDatasources[]?] | contains(["git-refs"]) | not
  ' "${DEVBASE_ROOT}/renovate.json"
  assert_success
}


@test "custom.openshift-oc overrides minimumReleaseAge to null and has a schedule" {
  local oc_ok
  oc_ok=$(jq -r '
    .packageRules[]
    | select(.matchDatasources | arrays | contains(["custom.openshift-oc"]))
    | (.minimumReleaseAge == null) and (.schedule | length > 0)
  ' "${DEVBASE_ROOT}/renovate.json")
  [[ "$oc_ok" == "true" ]] || { echo "custom.openshift-oc rule missing null override or schedule" >&2; return 1; }
}

@test "no standard datasource bypasses minimumReleaseAge via packageRules" {
  # Only custom.* datasources (no release timestamps) may set minimumReleaseAge
  # to null. Any other datasource that does so bypasses the 7-day supply-chain
  # policy silently — this test catches that.
  run jq -e '
    [.packageRules[]?
     | select(has("minimumReleaseAge") and .minimumReleaseAge == null)
     | .matchDatasources[]?
     | select(startswith("custom.") | not)]
    | length == 0
  ' "${DEVBASE_ROOT}/renovate.json"
  assert_success
}
