# OpenCode through nono

Select the **ai** pack during setup to install OpenCode, Codex and nono through
mise. The pack is optional and is not added to the default pack selection.

DevBase owns the host agent versions in `dot/.config/devbase/packages.yaml`:

| Tool | Stable release pin | Launch path |
| --- | --- | --- |
| OpenCode | `v1.19.4` | Managed nono launcher described below. |
| Codex | `0.164.0` (upstream tag `rust-v0.164.0`) | Host CLI; use `nono-wrapper codex` when the separate nono-wrapper is installed. |
| nono | `0.80.0` | Sandbox runtime. |

The nono-wrapper checkout does not install or pin host OpenCode/Codex versions.
Its container-test archives have independent pins for reproducibility. This AI
pack supplies the host binaries; Codex sandbox setup and launch remain the
separate wrapper's responsibility.

DevBase installs and pins the signed upstream **`nolabs-ai/opencode-v1@0.1.0`**
pack with nono. It supplies the sandbox profile, first-run directory hook,
OpenCode plugin, and `nono-sandbox` skill. The separate `nolabs-ai/opencode` pack
targets OpenCode 2; it is not compatible with the OpenCode 1.x pin used here.

## Start a session

Open a new shell after setup, change to your project or worktree root, and run:

```sh
opencode
opencode run "Explain the tests in this project"
```

The current physical directory is the writable workspace. Starting from home,
an ancestor of home, or a directory overlapping the managed launcher, mise
installation, or policy is refused. When using Git worktrees, start in the
worktree; metadata outside it may require additional upstream policy support.
The launcher also inspects the upstream pack's expanded filesystem grants and
refuses writable overlaps with managed executables, active profiles, and pack
files, including overlaps introduced by symlinks or custom installation paths.

Mise's native command wrapper routes Fish, Bash, and `mise exec -- opencode`
through the same launcher. A symlink at `$XDG_BIN_HOME/opencode` (normally
`~/.local/bin/opencode`) supports applications that do not activate mise, provided
that directory is on their PATH. DevBase refuses to replace a conflicting file.
Existing shell functions, aliases, and unrelated OpenCode installations can still
shadow the command: check `type -a opencode` after setup.

## What runs

The managed launcher lives at `$XDG_DATA_HOME/devbase/opencode/launcher`. Its
adjacent `runtime.json` records exact tool references, the mise executable/data
directory, and the required pack version. Binary lookup uses `mise --no-config
where` with those references: project tool selections cannot substitute the
sandbox executable, trigger tool installation, or execute mise project hooks
during lookup.
Setup verifies that both pinned executables are present before installing the
upstream pack and reporting AI-pack success.

The launcher requires the expected pack to be installed and pinned, then runs
the resolved OpenCode executable through `nono run --profile
nolabs-ai/opencode-v1`. No missing dependency, pack error, or sandbox failure
falls back to raw OpenCode. Ambient `NONO_*` options are cleared before launching
so shell settings such as `NONO_ALLOW=/` cannot silently widen this invocation.

OpenCode automatic updates are disabled and `opencode upgrade` is refused;
update through DevBase. Remote `attach` and `run --attach` are refused because
sandboxing a client does not confine tools executed by an external server.
These checks also apply when global options precede the subcommand. Unknown
leading options are refused; put a subcommand before its options and use full
option names for the default TUI invocation.

## Policy and credentials

The upstream pack defines the security policy. It allows networking by default,
grants OpenCode state and common developer caches, and protects credentials,
shell configuration/history, and browser data through nono's policy groups.
Its grants include more than just the workspace: inspect the effective policy
before using it with sensitive projects:

```sh
nono profile show nolabs-ai/opencode-v1
```

DevBase adds read access to mise-installed tools and mise configuration, plus
the XDG OpenCode runtime directories. It does not grant write access to the
managed launcher or mise binaries. The pack's plugin provides sandbox context
and denial diagnostics to OpenCode. Provider authentication follows OpenCode
and the upstream pack; DevBase does not provision API keys or enable credential
injection routes. Existing proxy environment variables remain available.

This is a sandboxed **managed launch path**, not a restriction against the owner
of the machine. Users can change their own configuration, override a mise
wrapper in a trusted project, invoke an installed binary by absolute path, or
install another copy. OS-enforced restrictions on those actions require a
separate managed-machine policy.

## Updates and troubleshooting

- AI tools use exact manifest pins. Renovate follows stable agent releases
  under the shared seven-day release-age policy; prereleases are excluded.
  OpenCode major upgrades are held for a joint launcher/pack compatibility
  review. Renovate extracts Codex versions from stable `rust-v` release tags;
  Aqua uses the resulting numeric version pin.
- The nono pack version is recorded as `nono_opencode_pack` in `packages.yaml`.
  Review registry publication/provenance dates and release notes before changing
  it; Renovate does not currently advance this registry pin. Version 0.1.0 was
  published/signed on 2026-10-12.
- Setup uses `nono pull` without `--force`, then `nono pin`. Conflicting plugin
  files or an installed OpenCode 2 pack must be resolved explicitly; personal
  files are not silently replaced. Pack verification or download failure fails
  setup rather than enabling an unprotected session.
- Re-run setup to repair a missing binary or pack. Deselecting the ai pack
  disables the managed fallback launcher; it does not remove user configuration
  or uninstall the upstream pack.
- For a denied operation, use the pack's diagnostics and `nono why`. Do not
  solve it by bypassing the wrapper or granting the whole home directory.
- Linux/WSL must provide the kernel sandbox features nono requires. Unsupported
  environments fail closed.

## Developer validation

`tests/opencode-sandbox.bats` covers selection, installation conflicts, exact
argument forwarding, failed sandbox startup, pack pinning, and workspace guards.
Set `DEVBASE_TEST_MISE_BIN` to the pinned mise binary for native shell dispatch
tests. Set `DEVBASE_TEST_NONO_BIN` to nono 0.80.0 for kernel enforcement tests;
also set `DEVBASE_TEST_OPENCODE_BIN` to OpenCode 1.19.4 for startup/configuration
validation. Native nono tests download the signed pack into isolated test homes
and require network access and kernel sandbox support. They do not call an AI
provider. Native test homes are created temporarily in the checkout because the
upstream pack intentionally allows temporary-file writes under `/tmp`.

See the [upstream OpenCode integration](https://nono.sh/docs/cli/clients/opencode)
and [pack registry](https://registry.nono.sh) for the pack's full behavior.
