# Codebase Analysis: `devbase-core` (round 2)

Second pass — covers everything not addressed by db1.md. Issues range from real bugs to
design smells to minor style nits.

---

## 1. Bugs

**`_install_mise_tools_whiptail_spinner`: `tee` masks `mise` exit code**
(`libs/install-mise.sh:441`)
The spinner runs `mise install … | tee` inside a `bash -c` subprocess. That subprocess
does **not** inherit `set -o pipefail` from the parent, so the pipeline exit code is
`tee`'s (always 0 on success), not `mise install`'s. A failing `mise install` is
silently swallowed; the warning branch is never reached. The gauge path avoids this by
using process substitution + a temp file; the gum path inherits `pipefail` because it
runs in-process. The spinner path is the odd one out.

**`DEVBASE_GLOBAL_WARNINGS=()` declaration is orphaned inside a doc comment**
(`libs/utils.sh:254–259`)
The doc comment at lines 254–258 documents `retry_command`, but `declare -ag
DEVBASE_GLOBAL_WARNINGS=()` at line 259 interrupts it. The declaration is undocumented
and visually belongs to the comment block above it. Readers looking for where the global
warning array is initialised will have to guess. The `add_global_warning` and
`show_global_warnings` functions that immediately follow are also without doc comments.

**`setup_ssh_config_includes` doc comment says "Returns: 0 always" but returns 1**
(`libs/configure-ssh-git.sh:15`)
The comment states `# Returns: 0 always`, but lines 18–19 contain
`validate_var_set "HOME" || return 1` and `validate_var_set "XDG_CONFIG_HOME" || return 1`.
Callers relying on the documented contract will silently skip error-handling.

**`setup_non_interactive_mode` checks `$SSH_KEY_PASSPHRASE` twice with identical logic**
(`libs/collect-user-preferences-common.sh:29,36`)
Line 29 checks `[[ -z "$SSH_KEY_PASSPHRASE" ]]`; after potentially setting
`DEVBASE_SSH_PASSPHRASE` from it, line 36 checks `[[ -z "${SSH_KEY_PASSPHRASE:-}" ]]`
again — the same variable with only a cosmetic `:-` difference. If the passphrase was
empty (line 29 true), the second check is always true. If it was non-empty (line 29
false), the second check is always false. The duplicated condition makes the intent
unclear and obscures the real branching logic.

**`install_mise_tools:541` iterates `$SELECTED_PACKS` as an unquoted string**
(`libs/install-mise.sh:541`)
`for pack in $SELECTED_PACKS` relies on word-splitting a plain string. This is
inconsistent with `core_runtimes`, which is correctly handled as a `local -a` array.
More importantly `SELECTED_PACKS` has no `DEVBASE_` prefix, unlike every other exported
preference variable. If an external environment happens to export `SELECTED_PACKS` the
function silently uses the wrong value.

---

## 2. Redundancy / Code Duplication

**`install_mise` and `update_mise_if_needed` duplicate the installer download/verify/run
block** (`libs/install-mise.sh:207–237` and `364–383`)
Both functions: download `$DEVBASE_URL_MISE_INSTALLER`, validate the file with `! -s` +
`grep -q "mise"` + `_verify_mise_installer_checksum`, then dispatch on `DEVBASE_TUI_MODE`
to run it. ~25 lines copied verbatim. Extracting a `_run_mise_installer()` helper would
eliminate the duplication and centralise the single-point-of-change for the installer
invocation.

**`validate_custom_dir` and `validate_optional_dir` are identical functions**
(`libs/validation.sh:152–170` and `200–225`)
Both: dereference a variable name, silently return 1 if empty, emit an error and return 1
if the directory does not exist, otherwise return 0. The only differences are the doc
comment wording and the default description string (`"custom directory"` vs
`"directory"`). One function is entirely redundant.

**`defaults.sh`: 10 getter functions with a 5-line boilerplate pattern**
(`libs/defaults.sh`)
Every `get_default_X()` is:

```bash
if [[ -n "${DEVBASE_DEFAULT_X:-}" ]]; then
    printf '%s' "${DEVBASE_DEFAULT_X}"
else
    printf '%s' "hardcoded-value"
fi
```

This is just `printf '%s' "${DEVBASE_DEFAULT_X:-hardcoded-value}"` — a single line. The
10 functions currently occupy ~60 lines and could each be collapsed to 3 (comment + body

- closing brace).

**`export PATH="${HOME}/.local/bin:${PATH}"` duplicated after each installer run**
(`libs/install-mise.sh:240` and `385`)
Both `install_mise` and `update_mise_if_needed` append `.local/bin` after running the
installer. If both execute in the same session, PATH gets the duplicate entry twice. At
minimum this should be guarded with `[[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]`.

---

## 3. Idiom / Style Issues

**`configure_ssh` uppercases key type via subprocess**
(`libs/configure-ssh-git.sh:166`)

```bash
key_type_upper=$(echo "${DEVBASE_SSH_KEY_TYPE}" | tr '[:lower:]' '[:upper:]')
```

Bash 4+ `${DEVBASE_SSH_KEY_TYPE^^}` is idiomatic, faster, and avoids two forks.

**`setup_ssh_config_includes` mixes `~/` and `${HOME}/` in the same function**
(`libs/configure-ssh-git.sh:22–23, 43, 58`)
Lines 22–23 use `~/.ssh`; lines 43 and 58 use `${HOME}/.ssh`. They expand identically,
but consistent use of `${HOME}/` throughout is more readable in scripts (where `~` is
sometimes not expanded in the way readers expect).

**`_parse_mise_tool_name` uses `echo` to pipe**
(`libs/install-mise.sh:101`)
`echo "$line" | grep -oE …` — if `$line` starts with `-n`, `-e`, or `-E`, POSIX `echo`
may interpret it as a flag. `printf '%s\n' "$line"` is the safe idiom.

**`get_mise_installed_version` uses `echo` for output**
(`libs/install-mise.sh:158`)
`echo "$version"` — consistent with other functions would be `printf '%s\n' "$version"`.

**`_bool_to_symbol` uses `echo`**
(`libs/collect-user-preferences-common.sh`)
Same `echo` → `printf` inconsistency.

**`setup.sh:27` traps TERM with an INT handler, exits 130**
(`setup.sh:22–27`)
`handle_interrupt` prints "cancelled by user (Ctrl+C)" and exits 130 (128 + SIGINT=2).
When SIGTERM fires the same handler, the process exits with 130 and the message "cancelled
by user (Ctrl+C)", which is both misleading to the user and wrong for process managers
(they expect exit 143 = 128 + SIGTERM=15 to confirm graceful termination). TERM needs its
own handler.

**`install-mise.sh:213`: installer content check is trivially weak**

```bash
if [[ ! -s "$mise_installer" ]] || ! grep -q "mise" "$mise_installer"; then
```

Any file that is non-empty and contains the string "mise" passes. This is not a
meaningful integrity check. At minimum it should check for the shebang or a known
function name from the real installer script.

---

## 4. Architecture / Design

**`write_user_preferences`: YAML written via bare heredoc with unescaped interpolation**
(`libs/collect-user-preferences-common.sh`)
Values like `DEVBASE_GIT_AUTHOR` and `DEVBASE_GIT_EMAIL` are expanded directly into the
heredoc. A git author name containing `:`, `#`, `[`, `"`, or a leading `-` will produce
invalid YAML. `yq` is already a mandatory dependency; values should be written with
`yq eval '.key = $value'` rather than interpolated by the shell.

**`check-requirements.sh`: `get_os_info` sources `/etc/os-release` on every call,
polluting the namespace each time**
(`libs/check-requirements.sh`)
`get_os_type`, `get_os_version`, `get_os_name`, and `get_os_version_full` each call
`get_os_info`, which re-`source`s `/etc/os-release` into the current shell. This:
(a) pollutes the namespace with ~15 variables (`ID`, `NAME`, `VERSION_ID`,
`PRETTY_NAME`, etc.) even when only one value is needed;
(b) re-reads the file on every call with no caching guard.
The fix is to populate a set of `_DEVBASE_OS_*` variables exactly once (with a `[[ -v ]]`
guard) and have the four getters reference those.

**`apply_gnome_terminal_theme`: 12 themes hardcoded as case-statement data**
(`libs/install-custom.sh`)
All color hex values live inside the function body. Adding or modifying a theme requires
editing the function. Extracting the data as a `declare -A` map at module level (keyed by
theme name) would make the function a pure dispatcher and the data independently
readable.

**`install-context.sh`: `export -f` makes four functions ambient in all child processes**
(`libs/install-context.sh`)
`export -f func` makes the function available in every subprocess spawned for the rest of
the session, including `bash -c`, external scripts, and any child process that sources
bash. This is a design smell: it enlarges the implicit API of every subprocess,
complicates debugging, and increases the attack surface. The explicit
`"$(declare -f fn); fn …"` pattern used elsewhere is more controlled.

**`_yq_read` inner function leaks to parent shell namespace**
(`libs/collect-user-preferences-common.sh`)
`_yq_read` is defined inside `load_saved_preferences`. Bash has no truly local functions;
after the first call, `_yq_read` persists for the remainder of the process and is
callable from anywhere. It should be defined at module level with a guard, or inlined.

**`envsubst_preserve_undefined` re-declares `runtime_vars` inline instead of using
`DEVBASE_RUNTIME_TEMPLATE_VARS`**
(`libs/utils.sh`)
The function maintains its own local copy of the runtime-variable list. The canonical
list is already `readonly -a DEVBASE_RUNTIME_TEMPLATE_VARS` in `validation.sh`. If a new
runtime var is added to the canonical list but forgotten here (or vice versa), filtering
silently breaks for that variable.

**`_download_file_get_cache_name`: no-extension filenames produce a garbled cache name**
(`libs/handle-network.sh`)
For a URL ending in `/mise_installer` (no `.` in the basename):

- `${base_name%.*}` → empty string
- `${base_name##*.}` → `mise_installer` (the whole name, not an extension)
The assembled cache name becomes something like `-v2.1.mise_installer`, which is wrong.
The function needs an explicit guard: `if [[ "$base_name" != *"."* ]]; then …`.

---

## 5. Security

**`setup_ssh_config_includes`: blocklist for `~/.ssh` copy is incomplete**
(`libs/configure-ssh-git.sh:54–59`)
The catch-all `*` case copies any file that is not `*.config`, `*.append`, `README*`, or
one of three blocklisted names. Files with special SSH meaning that are **not** blocked
include `authorized_keys2` (read by `sshd` as a secondary authorised-keys file),
`environment` (sets environment variables for SSH sessions), and `rc` (executed on
login). A blocklist is inherently incomplete; an allowlist of accepted extensions (e.g.,
`*.pub`, `*.pem`) would be safer.

**`write_user_preferences`: YAML injection via unescaped user-controlled strings**
(see §4 — also a security issue)
While the impact is limited to corrupting the local prefs file rather than RCE, this
pattern violates the principle that user-provided strings must never be interpolated
directly into structured formats without escaping.

**`setup_non_interactive_mode:39`: generated SSH passphrase written to disk in plaintext
with no cleanup trap**
(`libs/collect-user-preferences-common.sh:39`)

```bash
echo "$DEVBASE_SSH_PASSPHRASE" >"${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
chmod 600 "${DEVBASE_CONFIG_DIR}/.ssh_passphrase.tmp"
```

Even with `chmod 600`, if setup is interrupted before the file is cleaned up, the
passphrase persists unprotected. There is no `trap` to remove it on unexpected exit.
A named pipe or environment variable handoff would be preferable; at minimum a cleanup
trap should be registered immediately after the file is written.

**`verify_mise_checksum` silently skips verification on non-x86_64**
(`libs/install-mise.sh:28–30`)
On ARM (increasingly common in dev environments) checksum verification is skipped with a
warning. The binary is still executed. The warning is easily missed in automated runs.
Either provide ARM checksums or fail hard with a clear message rather than silently
proceeding with an unverified binary.

**`verify_mise_checksum` architecture string inconsistency: `x86_64` vs `x64`**
(`libs/install-mise.sh:28, 60`)
The guard checks `uname -m` for `x86_64` but the binary pattern is
`mise-v${version}-linux-x64`. These match the same architecture but the two names are
inconsistent. If someone adds an ARM path, they will need to know to map `aarch64` →
`arm64` (mise's naming), which is not evident from the existing code.

---

## 6. Test Quality

**`setup_ssh_config_includes` called without `run` as test setup**
(`tests/libs-configure-ssh-git.bats:119`)
Line 119: `setup_ssh_config_includes >/dev/null 2>&1` is called directly (not via `run`)
before the `stat` assertion. If it fails, the test continues and the `stat` output will
be absent or unexpected, producing a confusing assertion failure rather than a clear
"function returned non-zero" message. It should use `run --separate-stderr … &&
assert_success` or at minimum `|| return 1`.

**`configure_single_fish_completion 'helm'` called without `run`**
(`tests/libs-configure-completions.bats:54`)
Same pattern: `configure_single_fish_completion 'helm' >/dev/null 2>&1` then
`assert_file_exists`. If the function fails the assert_file_exists message will not
identify the real cause.

**No tests for `update_mise_if_needed`**
(`libs/install-mise.sh:332–390`)
The function contains non-trivial version comparison logic (`sort -V`, `printf '%s\n%s\n'
… | sort -V | tail -1`) with no dedicated test coverage. A version comparison that
returns the wrong ordering (e.g., `2.10` < `2.9` under lexicographic sort) would silently
skip an upgrade.

**No tests for `envsubst_preserve_undefined` variable filtering**
(`libs/utils.sh`)
The runtime-variable exclusion logic has no dedicated test. A typo in the excluded list
would silently expose runtime variables to `envsubst` substitution with empty values.

**No tests for `apply_gnome_terminal_theme`**
(`libs/install-custom.sh`)
The function contains 12 theme branches and constructs dconf paths from user input with
no coverage. A regression in any theme or a bad dconf path would only surface at runtime.

---

## 7. Minor / Consistency

- **`SELECTED_PACKS` vs `DEVBASE_SELECTED_PACKS`** (`libs/install-mise.sh:541`) — The
  loop uses the un-prefixed `$SELECTED_PACKS`, inconsistent with the project's
  `DEVBASE_` naming convention for all preference variables. If both are set they silently
  diverge.

- **`update_mise_if_needed` has no doc comment** (`libs/install-mise.sh:332`) — Missing
  the standard `# Brief / Params / Uses / Returns` block, unlike every other public
  function in the file.

- **`_wt_gauge_is_running` has no doc comment** — Called at `install-mise.sh:512` but
  undocumented, inconsistent with the rest of the codebase.

- **`install_mise` hardcodes `linux-x64` as the checksum pattern suffix**
  (`libs/install-mise.sh:60`) — If ARM support is ever added, there is no clear path to
  extend this; the architecture mapping from `uname -m` to mise's naming scheme is
  implicit.

- **`validate_not_empty` and `validate_dir_exists` have an explicit `return 0` at end**
  (`libs/validation.sh:68, 98`) — Trailing `return 0` is a no-op and inconsistent with
  `validate_var_set`, `validate_url`, etc., which omit it.
