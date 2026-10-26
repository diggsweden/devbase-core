<!--
SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government

SPDX-License-Identifier: CC0-1.0
-->

# AI tools through nono-wrapper

Select the optional **ai** pack during DevBase setup. DevBase installs stable
host OpenCode, Codex and nono versions through mise. It does not add the AI
pack to the default selection.

| Responsibility | Owner |
| --- | --- |
| Host agent and sandbox-runtime versions | DevBase's `packages.yaml`, updated by Renovate. |
| Agent command dispatch | Fish/Bash functions and Mise wrappers, delegated to `nono-wrapper`. |
| Sandbox profiles, official signed packs, plugins and session reports | `nono-wrapper`. |
| Reproducible container-test agent archives | `nono-wrapper`'s independent test pins. |

## Setup and launch

Install [nono-wrapper](https://codefloe.com/itiquette/nono-wrapper) and its
profiles once, following its installation guide (`just install-local` from
that checkout). Put its installed executable, normally `~/.local/bin`, on
PATH. DevBase supplies the agent binaries; nono-wrapper supplies their policy.

Open a new shell, change to a project directory, and run:

```sh
opencode
codex
```

DevBase's `opencode` and `codex` Fish functions call `command nono-wrapper`
with the agent name and exact arguments. The missing-wrapper message guides
users to install the wrapper and profiles; it never starts a raw agent or
suggests bypassing the sandbox. These Fish functions also cover a session
without Mise activation.

Setup also appends the same thin entry points to `.bashrc` before the Fish
handoff. Bash sessions that stay in Bash do not depend on Mise activation to
get the sandboxed default. The block is installed once, preserving personal
configuration. Linked `.bashrc` files are preserved by the configuration
lifecycle; their owner must source the supplied agent block manually.

For activated shells and `mise exec`, the generated configuration supplies
the same delegation:

```toml
[wrappers.opencode]
command = "nono-wrapper"
args = ["opencode"]

[wrappers.codex]
command = "nono-wrapper"
args = ["codex"]
```

Mise handles activated shells and `mise exec -- opencode` or
`mise exec -- codex`. It removes its own command wrapper from lookup before
calling the delegate. nono-wrapper resolves the real agent binary and applies
one sandbox using its bundled and user profiles. There is no second DevBase
launcher, runtime metadata file or independent profile lifecycle.

Delegation follows logical package names (`opencode`, `codex`, `nono`), not
backend strings. Selecting a registry name, another release backend or backend
options in an organization overlay changes installation without removing the
agent's sandbox delegate. Package selection and skip tags still apply.

A missing nono-wrapper fails launch; there is no fallback to an unsandboxed
agent. Applications outside these shell entry points and Mise activation use
`nono-wrapper opencode` or `nono-wrapper codex` explicitly. Personal aliases
and unrelated installations can shadow commands: inspect
`type -a opencode codex` after setup.

## Versions and permissions

The current manifest pins OpenCode `v1.19.4`, Codex `0.164.0` (upstream tag
`rust-v0.164.0`) and nono `0.80.0`. Renovate follows stable agent releases under
the shared seven-day release-age policy. OpenCode major upgrades and nono 1.x
are held for a joint compatibility review with nono-wrapper's profiles.
Codex's numeric Aqua pin is extracted from its stable `rust-v` release tags.

Use nono-wrapper's configuration interface for persistent permissions, from
your normal terminal outside the sandbox:

```sh
nono-wrapper config opencode allow-domain api.github.com
nono-wrapper config codex allow-tcp-port 3000
nono-wrapper config codex show
```

TCP port grants are not loopback-only: on Linux they can permit direct
connections to non-loopback addresses on the granted port, bypassing domain
filtering even with an offline profile. See nono-wrapper's network allowance
matrix for exact domains, wildcards, HTTPS endpoint rules and removal.
Changes apply to new sessions. Run `nono-wrapper verify` to check the installed
offline profiles; it does not validate account login or custom permissions.

The owner can still select a raw binary or override trusted mise settings.
This is a managed launch default, not an OS policy against the machine owner.

## Development checks

`tests/config-preservation.bats` checks Bash dispatch without activation,
configuration preservation, idempotence and placement before the Fish handoff.
`tests/ai-fish-functions.bats` checks automatic Fish delegation, exact
arguments, streams, exit status, function shadowing and a missing wrapper.
`tests/ai-tools.bats` checks selected versions, delegation for both agents,
exact arguments, raw-binary lookup and a missing delegate. Set
`DEVBASE_TEST_MISE_BIN` to mise for native dispatch tests. Combined native
validation uses the generated AI configuration with nono-wrapper's isolated
integration suite; see that repository's development notes.
