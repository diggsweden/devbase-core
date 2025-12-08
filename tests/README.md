# DevBase Core Tests

<!--
SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government

SPDX-License-Identifier: CC0-1.0
-->

BATS test suite for DevBase Core.

## Requirements

- [BATS](https://github.com/bats-core/bats-core) - Bash Automated Testing System
- BATS helper libraries (installed automatically via `setup-bats-libs.sh`):
  - [bats-support](https://github.com/bats-core/bats-support) - Supporting library with common functions
  - [bats-assert](https://github.com/bats-core/bats-assert) - Assertion library
  - [bats-file](https://github.com/bats-core/bats-file) - File system assertions
  - [bats-mock](https://github.com/jasonkarns/bats-mock) - Command mocking for testing

## Setup

Install BATS and helper libraries:

```bash
# Install BATS via mise
mise install

# Install BATS helper libraries
./tests/setup-bats-libs.sh
```

## Running Tests

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/setup.bats

# Run with verbose output
bats -tap tests/

# Run tests matching a pattern
bats -f "verify" tests/
```

### Testing Techniques Used

- **Isolated environments**: All tests use `temp_make`/`temp_del` for safe temp directories
- **Mocking**: Uses `bats-mock` to stub external commands (git, systemctl, apt-get)
- **No host impact**: Tests never modify the host system

## Writing Tests

Follow BATS best practices:

1. Use `bats_require_minimum_version 1.13.0`
2. Load helper libraries: `bats-support`, `bats-assert`, `bats-file`, `bats-mock`
3. Use `setup()` and `teardown()` with `temp_make`/`temp_del` for isolated test environments
4. Use `mock_create` from bats-mock to mock external commands
5. Use descriptive test names
6. Add comments for complex assertions

### Example: Basic Test

```bash
#!/usr/bin/env bats

bats_require_minimum_version 1.13.0

load "${BATS_TEST_DIRNAME}/libs/bats-support/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-assert/load.bash"
load "${BATS_TEST_DIRNAME}/libs/bats-file/load.bash"

setup() {
  TEST_DIR="$(temp_make)"
  export DEVBASE_ROOT="${BATS_TEST_DIRNAME}/.."
}

teardown() {
  temp_del "$TEST_DIR"
}

@test "function creates expected file" {
  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/myscript.sh'
    my_function '${TEST_DIR}/output'
  "

  assert_success
  assert_file_exists "${TEST_DIR}/output"
}
```

### Example: Using Mocks

```bash
load "${BATS_TEST_DIRNAME}/libs/bats-mock/stub.bash"

@test "function calls expected command" {
  # Mock the 'git' command
  git="$(mock_create)"
  mock_set_output "${git}" "main" 1  # First call returns "main"

  export PATH="${BATS_TEST_BINDIR}:${PATH}"
  ln -s "${git}" "${BATS_TEST_BINDIR}/git"

  run bash -c "
    export DEVBASE_ROOT='${DEVBASE_ROOT}'
    source '${DEVBASE_ROOT}/libs/myscript.sh'
    get_default_branch
  "

  assert_success
  assert_output "main"
}
```

## CI Integration

Tests are automatically run in CI via GitHub Actions (see `.github/workflows/test.yml`).
