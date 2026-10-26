#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: MIT

# Bats isolates tests; fixture scripts expand their variables when executed.
# shellcheck disable=SC2016,SC2030,SC2031

bats_require_minimum_version 1.13.0
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'libs/bats-file/load'
load 'test_helper'

setup() {
  common_setup_isolated
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
  unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_TERMINAL_PROMPT=0
  export VALIDATION_LOG="$TEST_DIR/validated"
  mkdir -p "$TEST_DIR/bin" "$TEST_DIR/hooks/post-commit.d" "$TEST_DIR/hooks/post-rewrite.d" "$TEST_DIR/empty-templates"
  local templates="$DEVBASE_ROOT/devbase_files/git-hooks-templates"
  cp "$templates/post-commit" "$templates/post-rewrite" "$templates/commit-validation.sh" "$TEST_DIR/hooks/"
  cp "$templates/post-commit.d/01-conventional-commits.sh" "$TEST_DIR/hooks/post-commit.d/"
  cp "$templates/post-rewrite.d/01-conventional-commits.sh" "$TEST_DIR/hooks/post-rewrite.d/"
  chmod +x "$TEST_DIR/hooks/post-commit" "$TEST_DIR/hooks/post-rewrite" \
    "$TEST_DIR/hooks/post-commit.d/01-conventional-commits.sh" "$TEST_DIR/hooks/post-rewrite.d/01-conventional-commits.sh"

  # Real Git drives the hook lifecycle; only gommitlint is replaced. The fake
  # requires an explicit committed object and detects invalid/temporary subjects.
  cat >"$TEST_DIR/bin/gommitlint" <<'SH'
#!/usr/bin/env bash
[[ $# == 4 && $1 == validate && $2 == -v && $3 == --ref ]] || exit 2
commit=$(git rev-parse --verify "$4^{commit}") || exit 2
printf '%s\n' "$commit" >>"$VALIDATION_LOG"
subject=$(git show -s --format=%s "$commit") || exit 2
case "$subject" in
  invalid*|\#*) printf 'invalid subject: %s\n' "$subject"; exit 1 ;;
esac
SH
  chmod +x "$TEST_DIR/bin/gommitlint"
  export PATH="$TEST_DIR/bin:$PATH"
  : >"$VALIDATION_LOG"
  init_repository sha1
}

teardown() {
  common_teardown
}

init_repository() {
  local format=$1
  mkdir -p "$TEST_DIR/repo-$format with spaces"
  cd "$TEST_DIR/repo-$format with spaces" || return 1
  git init -q --initial-branch=main --object-format="$format" --template="$TEST_DIR/empty-templates"
  git config user.name 'Hook Test'
  git config user.email hook-test@example.invalid
  git config commit.gpgsign false
  git config core.hooksPath "$TEST_DIR/hooks"
}

fixture_commit() {
  printf '%s\n' "$1" >fixture.txt
  git add fixture.txt
  # Fixture creation does not exercise the hooks and must not call host hooks.
  git -c core.hooksPath=/dev/null commit -q -s -m "$1"
}

squash_history() {
  cat >"$TEST_DIR/squash-editor" <<'SH'
#!/usr/bin/env bash
sed -i '2,$s/^pick /squash /' "$1"
SH
  chmod +x "$TEST_DIR/squash-editor"
  GIT_SEQUENCE_EDITOR="$TEST_DIR/squash-editor" git rebase --interactive --root
}

@test "normal commits and amendments are each validated once" {
  fixture_commit 'feat: initial'
  printf 'next\n' >fixture.txt
  git add fixture.txt
  run git commit -s -m 'feat: next'
  assert_success
  assert_output --partial '1 commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" "$(git rev-parse HEAD)"

  : >"$VALIDATION_LOG"
  run git commit --amend --no-edit
  assert_success
  assert_output --partial '1 commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" "$(git rev-parse HEAD)"
}

@test "squashing four commits validates only the final object" {
  fixture_commit 'feat: first'
  fixture_commit 'feat: second'
  fixture_commit 'feat: third'
  fixture_commit 'feat: fourth'

  run squash_history
  assert_success
  refute_output --partial 'validation issues'
  assert_output --partial '1 commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" "$(git rev-parse HEAD)"
  assert_equal "$(git rev-list --count HEAD)" 1
}

@test "rebase reports an invalid earlier commit even with a valid HEAD" {
  fixture_commit 'feat: first'
  fixture_commit 'invalid earlier message'
  fixture_commit 'feat: last'

  run git rebase --interactive --force-rebase --root
  assert_success
  assert_output --partial 'invalid subject: invalid earlier message'
  assert_output --partial '1 of 3 commit(s) could not pass validation'
  refute_output --partial '3 commit(s) validated'
  assert_equal "$(sort "$VALIDATION_LOG")" "$(git rev-list HEAD | sort)"
}

@test "post-commit defers for both Git rebase state directories" {
  fixture_commit 'feat: initial'
  local state state_dir
  for state in rebase-merge rebase-apply; do
    state_dir=$(git rev-parse --git-path "$state")
    mkdir "$state_dir"
    run bash "$TEST_DIR/hooks/post-commit"
    assert_success
    assert_output ''
    rm -r "$state_dir"
  done
  assert_equal "$(cat "$VALIDATION_LOG")" ''
}

@test "squash validation works in a SHA-256 linked worktree" {
  init_repository sha256
  fixture_commit 'feat: first'
  git worktree add -q -b topic "$TEST_DIR/linked worktree" HEAD
  cd "$TEST_DIR/linked worktree" || return 1
  fixture_commit 'feat: second'
  fixture_commit 'feat: third'

  run squash_history
  assert_success
  assert_output --partial '1 commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" "$(git rev-parse HEAD)"
}

conflicting_history() {
  fixture_commit 'feat: base'
  git switch -q -c topic
  fixture_commit 'feat: topic'
  git switch -q main
  fixture_commit 'feat: main'
  git switch -q topic
}

@test "conflicted rebase validates only after continuation" {
  conflicting_history
  run git rebase main
  assert_failure
  refute_output --partial 'commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" ''

  printf 'resolved\n' >fixture.txt
  git add fixture.txt
  run git rebase --continue
  assert_success
  assert_output --partial '1 commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" "$(git rev-parse HEAD)"
}

@test "aborting a conflicted rebase does not claim validation passed" {
  conflicting_history
  run git rebase main
  assert_failure
  run git rebase --abort
  assert_success
  refute_output --partial 'commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" ''
}

@test "post-rewrite preserves the complete mapping for every custom hook" {
  fixture_commit 'feat: initial'
  local commit
  commit=$(git rev-parse HEAD)
  export OBSERVED_MAP="$TEST_DIR/observed-map"
  cat >"$TEST_DIR/hooks/post-rewrite.d/99-observer.sh" <<'SH'
#!/usr/bin/env bash
[[ $1 == rebase ]] || exit 1
cat >"$OBSERVED_MAP"
SH
  chmod +x "$TEST_DIR/hooks/post-rewrite.d/99-observer.sh"
  printf '%s %s\n%s %s\n' "$commit" "$commit" "$commit" "$commit" >"$TEST_DIR/mapping"

  run bash -c '"$TEST_DIR/hooks/post-rewrite" rebase <"$TEST_DIR/mapping"'
  assert_success
  assert_output --partial '1 commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" "$commit"
  run cmp "$TEST_DIR/mapping" "$OBSERVED_MAP"
  assert_success
}

@test "invalid rewrite mappings are advisory without running the validator" {
  fixture_commit 'feat: initial'
  printf '%s --help\n' "$(git rev-parse HEAD)" >"$TEST_DIR/mapping"
  run bash -c '"$TEST_DIR/hooks/post-rewrite" rebase <"$TEST_DIR/mapping"'
  assert_success
  assert_output --partial 'validation incomplete'
  refute_output --partial 'commit(s) validated'
  assert_equal "$(cat "$VALIDATION_LOG")" ''
}

@test "unresolvable commit objects do not claim validation passed" {
  fixture_commit 'feat: initial'
  printf '%s deadbeef\n' "$(git rev-parse HEAD)" >"$TEST_DIR/mapping"
  run bash -c '"$TEST_DIR/hooks/post-rewrite" rebase <"$TEST_DIR/mapping"'
  assert_success
  assert_output --partial 'Cannot resolve commit deadbeef'
  assert_output --partial '1 of 1 commit(s) could not pass validation'
  assert_equal "$(cat "$VALIDATION_LOG")" ''
}
