# DevBase Usage Guide

What DevBase changes on your machine, how the installed tools fit together, and the commands DevBase adds.
Generic tool usage is not repeated here: the full list of installed tools is in the
[Tools Matrix](tools-matrix.adoc), every key binding is in [Keybindings](keybindings.md),
and each tool documents itself.

```bash
tldr <tool>        # worked examples; DevBase seeds the page cache during setup
<tool> --help      # exact options for the installed version
```

Tools installed through mise (aqua releases) ship no man pages, so `man zellij` or `man k9s` will not work;
use `tldr` or the upstream documentation linked in the Tools Matrix instead. `man` for distribution packages
renders through bat with syntax highlighting (`MANPAGER`).

## Table of Contents

- [DevBase Commands](#devbase-commands)
- [What DevBase Changes](#what-devbase-changes)
  - [Fish Shell](#fish-shell)
  - [Zellij](#zellij)
  - [Prompt, Search and File Managers](#prompt-search-and-file-managers)
  - [Git](#git)
  - [Editors](#editors)
  - [Containers and Kubernetes](#containers-and-kubernetes)
  - [Security](#security)
  - [Code Quality](#code-quality)
  - [Languages and mise](#languages-and-mise)
  - [Desktop, Fonts and Browsers](#desktop-fonts-and-browsers)
- [Workflows](#workflows)
  - [Commit Safely](#commit-safely)
  - [Scan a Project Before Release](#scan-a-project-before-release)
  - [Container and Cluster Loop](#container-and-cluster-loop)
  - [Keep the Workstation Current](#keep-the-workstation-current)
- [SSH Keys](#ssh-keys)
- [Proxy Configuration Reference](#proxy-configuration-reference)

## DevBase Commands

**DevBase Commands:**

**devbase-proxy** - *Only installed when using custom proxy configuration* - see [Custom Configuration](customization.adoc#proxy-configuration)

Manage corporate proxy settings easily:

```bash
devbase-proxy on      # Enable proxy settings
devbase-proxy off     # Disable proxy settings
devbase-proxy status  # Show current proxy status
```

- Configures HTTP_PROXY, HTTPS_PROXY, NO_PROXY
- Automatically configures APT and Snap proxies
- Uses proxy settings from Fish config (set during installation from DEVBASE_PROXY_HOST/PORT)

**devbase-theme** - Set consistent themes across CLI tools (authoritative list in `libs/theme-registry.sh`):

```bash
# Everforest (default)
devbase-theme everforest-dark
devbase-theme everforest-light

# Catppuccin
devbase-theme catppuccin-mocha  # Dark
devbase-theme catppuccin-latte  # Light

# Tokyo Night
devbase-theme tokyonight-night  # Dark
devbase-theme tokyonight-day    # Light

# Gruvbox
devbase-theme gruvbox-dark
devbase-theme gruvbox-light
```

Affects: bat, delta, btop, eza, FZF, Neovim, vifm, K9s, Lazygit, Zellij, Windows Terminal (WSL), Ghostty (Linux), VSCode

**devbase-update** - Update DevBase core and re-run setup. The rerun applies your saved preferences without asking again (`setup.sh --keep-preferences`); the only prompts left are the update confirmation (skipped with `--yes`) and sudo:

```bash
# Update to latest tag
devbase-update

# Update to a specific ref (branch or tag)
devbase-update --ref feat/misc-fixes

# Snooze update prompts for N hours
devbase-update --snooze 24

# Clear update snooze
devbase-update --unsnooze

# Apply an available update without the confirmation prompt
devbase-update --yes
```

Note: when `--ref` is used, the persisted core repo at `~/.local/share/devbase/core` is pinned to that ref during the setup run. SHA refs are not supported.

A fresh install can be pinned the same way with `./setup.sh --ref <ref>` or the `DEVBASE_CORE_REF` environment variable - see [Test a Branch or Pull Request](development.adoc) in the Development Guide.

**Theme Provenance:**

| Tool | Theme Source | Notes |
|------|--------------|-------|
| **btop** | Official | 10 from [btop official repo](https://github.com/aristocratos/btop/tree/main/themes), 2 from [catppuccin/btop](https://github.com/catppuccin/btop) |
| **k9s** | Official | 8 from [k9s official skins](https://github.com/derailed/k9s/tree/master/skins), 2 from [catppuccin/k9s](https://github.com/catppuccin/k9s) |
| **eza** | Official + Custom | 14 from [eza-community/eza-themes](https://github.com/eza-community/eza-themes), 2 custom (nord.yml, solarized-light.yml) |
| **Windows Terminal** | Mixed | Uses built-in Solarized themes, custom JSON for others (Nord, Dracula, Everforest, etc.) |
| **Ghostty** | Built-in | Uses [Ghostty built-in themes](https://ghostty.org/) via theme names |
| **bat/delta** | Built-in | Uses bat/delta built-in syntax themes |
| **FZF** | Custom | Custom color schemes matching theme palettes |
| **Neovim** | Plugin | Uses official theme plugins (everforest, catppuccin, tokyonight, gruvbox, nord, dracula, solarized) |
| **vifm** | Community | Uses [vifm community themes](https://github.com/vifm/vifm-colors) |
| **Lazygit** | Built-in | Uses built-in light/dark mode |
| **Zellij** | Configuration | Theme colors defined in config (no separate theme files) |
| **VSCode** | Extensions | Requires corresponding theme extensions to be installed |

**Note:** All custom themes reference official color palettes from their respective projects (Nord, Dracula, Solarized, Everforest, Catppuccin, Tokyo Night, Gruvbox) to ensure visual consistency.

**devbase-reconfigure** - Change your preferences (editor and key bindings, theme, font, packs, tools, Git identity) by rerunning setup interactively with the saved answers preselected:

```bash
devbase-reconfigure                 # walk through the setup questions again
devbase-reconfigure --tui=whiptail  # options are passed to setup.sh
```

**devbase-font** - Set fonts for terminals and editors (authoritative list in `libs/font-registry.sh`):

```bash
# Available fonts
devbase-font jetbrains-mono  # JetBrains Mono - Excellent readability
devbase-font firacode        # Fira Code - Extensive ligatures
devbase-font cascadia-code   # Cascadia Code - Microsoft font
devbase-font monaspace       # Monaspace - Superfamily (default)
```

Affects: GNOME Terminal, Ghostty, VSCode  
⚠️ Requires restart: Close and reopen terminals/editors for changes to take effect

**devbase-citrix** - Download and install Citrix Workspace App (non-WSL only):

```bash
devbase-citrix --check  # Show available version
devbase-citrix          # Download and install
devbase-citrix --help   # Show help
```

Installs `icaclient` and `ctxusb` packages. For smart card support, enable pcscd: `sudo systemctl enable --now pcscd`

**devbase-firefox-opensc** - Configure Firefox for smart card support (non-WSL only):

```bash
devbase-firefox-opensc  # Add OpenSC PKCS#11 module to Firefox
```

Enables smart card authentication in Firefox. Run after first Firefox launch if profile didn't exist during installation.

## What DevBase Changes

### Fish Shell

Fish is the interactive shell; Bash stays the login shell and hands over to Fish for interactive sessions
(`bash` from Fish gives you a plain Bash again). Scripts with a `#!/bin/bash` shebang are unaffected.

- **Key bindings**: the *Vim-style* setup choice enables Fish's vi mode, *Emacs-style* keeps the defaults.
  `Alt+y` accepts the autosuggestion in both. Details in [Keybindings](keybindings.md#fish).
- **Aliases** (`~/.config/fish/conf.d/00-aliases.fish` and `02-aliases.fish`):
  `ls` → `eza --icons=auto`, `docker` → `podman`, `vi`/`vim` → `nvim`, `vimbare` → `nvim -u NONE -N`,
  `e` → `$EDITOR`, `se` → `sudo $EDITOR`, `fishconfig` edits `config.fish`, `bat` → `batcat` on Debian packages.
  Vim-style setups also get `v`, `view` and `vimrc`.
- **Environment** (`00-0-environment.fish`): XDG paths, `EDITOR`/`VISUAL`, `MANPAGER="bat -plman"`,
  `RIPGREP_CONFIG_PATH` → `~/.config/ripgrep/config` (smart case, hidden files, long-line limits),
  `GH_PAGER`/`GLAB_PAGER` → delta, `PIPX_COOLDOWN=7`, `DOCKER_HOST` → the rootless Podman socket,
  `SSH_AUTH_SOCK` → the user ssh-agent service, Node and Java CA settings when custom certificates are installed.
- **Colors**: `LS_COLORS` is generated by vivid for the DevBase theme; eza reads it.
- **Startup**: mise activation, ssh-agent key loading, the DevBase update check (`devbase-update --snooze 24` silences it),
  Zellij autostart when enabled.
- **Personal files**: anything in `conf.d/` that DevBase does not ship is preserved; files sort by name, so an override
  of `EDITOR` must sort before `01-keybindings.fish` (see [Personalization](personalization.adoc#editor-preference)).
- **Completions**: setup generates fish completions for the mise-installed tools that can print them
  (gh, glab, k9s, argocd, tkn, cosign, syft, gitleaks, trivy, oc, kubectl, k6, zellij, starship, yq, fd, rg, bat, delta,
  jwt, podman, buildah, skopeo, slsa-verifier, rumdl, taplo, lychee, tree-sitter, just, mise).

### Zellij

- **Autostart** is off by default. `DEVBASE_ZELLIJ_AUTOSTART=true` starts Zellij in new terminals (never over SSH or on the
  Linux console); `ZELLIJ_AUTO_ATTACH=true` attaches to an existing session; `ZELLIJ_AUTO_EXIT=true` closes the shell when
  Zellij exits. Set them in a personal `conf.d` file.
- **Keys**: DevBase adds `Alt+d` (new pane below) and `Alt+r` (new pane right). The default Zellij preset also binds
  `Ctrl+p/n/o/s/h/t/q/g`, which collide with Vim, fish vi mode and lazygit; `Ctrl+g` locks Zellij so the key reaches the
  application. See [Keybindings](keybindings.md#zellij).
- **Clipboard**: `wl-copy`, `xclip`, `xsel` or Windows `clip.exe` when present; otherwise Zellij copies through the
  terminal (OSC 52). A shell startup hook keeps `~/.config/zellij/config.kdl` in step with the environment.
- **Theme**: set by `devbase-theme`; the shell is Fish; mouse mode is on.

### Prompt, Search and File Managers

- **Starship**: `~/.config/starship/starship.toml` is created only when absent; an existing `~/.config/starship.toml`
  or `STARSHIP_CONFIG` wins. Shows git state, command duration, Python venv and the Kubernetes context
  (visible in YAML/k8s directories or whenever `KUBECONFIG` is set). In vi mode the prompt character flips to `<`.
- **fzf.fish**: `Ctrl+R` history, `Ctrl+Alt+F` files, `Ctrl+Alt+L` git log, `Ctrl+Alt+S` git status,
  `Ctrl+Alt+P` processes, `Ctrl+V` variables. Directory previews use eza, diff previews use delta,
  `Ctrl+/` toggles the preview window. `fd` honours `fzf_fd_opts` (hidden files, no `.git`).
- **zoxide**: `z <dir>` jumps to frequently used directories; `zi` picks interactively.
- **lf and vifm** are both installed and both Vim-keyed. lf is the lightweight default; vifm is the two-pane
  alternative with a Vim-like command line. Both open files with the editor chosen during setup (`EDITOR` / `vicmd`),
  and `vifm` uses the DevBase colorscheme. `tldr lf`, `tldr vifm`.
- **bat, eza, ripgrep, fd, btop, delta** follow the DevBase theme where the tool supports one
  (`BAT_THEME`, delta `syntax-theme`, btop theme file, eza via `LS_COLORS`).

### Git

- **Config** (`~/.config/git/config`, managed; personal settings go in `~/.gitconfig`):
  delta as pager with side-by-side diffs and `n`/`N` section navigation, `zdiff3` conflict style,
  `rerere` enabled, `rebase.autoStash` and `rebase.updateRefs`, `push.default simple` with `autoSetupRemote`,
  default branch `main`, global ignores in `~/.config/git/ignore`, editor from the setup choice.
- **Aliases**: `cs` (commit --signoff), `retris` (rebase -i --signoff --gpg-sign), `pull-re`, `push-force`
  (--force-with-lease), `gc-aggressive`, `date-now`.
- **Signing**: SSH signing with the DevBase key, `allowed_signers` in `~/.config/ssh/`. Signing is required only when a
  key exists; a setup without a key writes `commit.gpgsign = false` and says so
  ([Personalization](personalization.adoc#git-configuration)).
- **Hooks** (on by default, `~/.config/git/git-hooks`, dispatcher per hook running `*.d/*.sh`):
  `pre-commit.d/01-secrets-scan.sh` runs `gitleaks git --pre-commit --staged` and blocks on findings;
  `prepare-commit-msg.d/01-add-issue-ref.sh` adds `Refs: PROJ-123` from the branch name;
  `post-commit.d/01-conventional-commits.sh` validates the message with gommitlint (non-blocking).
  The secret scanner honors `GITLEAKS_CONFIG`, then `GITLEAKS_CONFIG_TOML`, then root `.gitleaks.toml`, then
  `development/gitleaks/gitleaks.toml`, falling back to built-in rules when none is configured.
  `commit-msg.d/` and `pre-push.d/` are empty extension points. Disabling and per-repository overrides are in
  [Customization](customization.adoc#git-hooks).
- **lazygit**: diffs render through delta in the theme's dark or light mode (`git.diffRenderers`), the editor follows
  `EDITOR`, Nerd Font icons are on.
- **gh / glab**: both page through delta (`GH_PAGER`, `GLAB_PAGER`). Completions are generated.
- **git-cliff** generates changelogs from conventional commits; **gommitlint** validates them (`gommitlint validate`).

### Editors

- **Neovim + LazyVim**: installed when selected and only if `~/.config/nvim` is absent; existing configurations are never
  touched. `lua/plugins/colorscheme.lua` is generated by `devbase-theme` for the selected theme (setup and later runs),
  and `treesitter.lua` adds parsers for fish, Dockerfile, git files, diff, ssh config and HCL. Leader key is `Space`;
  `<leader>?` shows keys. Reset plugins with `rm -rf ~/.local/share/nvim && nvim --headless "+Lazy! sync" +qa`.
- **VS Code**: core extensions plus the selected packs' extensions come from `packages.yaml`; setup installs them when the
  *VS Code extensions* preference is on, otherwise `devbase-vscode-extensions` (`--list`, `--dry-run`) does. The Neovim
  extension is optional and prompted; its settings point at the mise Neovim and set the extension-host affinity.
  On WSL the command targets the Remote-WSL instance. See [Editor Setup](editor-setup.adoc).
- **IntelliJ IDEA** (Java pack, optional): `idea` alias, `idea64.vmoptions` seeded once per IDE version, Google Java style
  and Checkstyle XML under `~/.config/devtools/` for import. DBeaver, JMC, VisualVM and KeyStore Explorer come with the pack.

### Containers and Kubernetes

- **Podman** is rootless; `docker` is an alias, `DOCKER_HOST` points at `podman.socket` (user service enabled by setup).
  Setup and updates never touch your containers, images or volumes,
  and `docker compose` / `podman compose` use the mise Compose binary as provider. Testcontainers reads
  `~/.testcontainers.properties`. `podman generate systemd` is deprecated; use Quadlet units in
  `~/.config/containers/systemd/`.
- **Registries**: `~/.config/containers/registries.conf` is written from the organization configuration when a registry
  mirror is set.
- **kubectl and oc** come from the OpenShift mirror, with completions.
- **k9s**: skin follows the DevBase theme and reloads live (`ui.reactive`), the GitHub version check is off, the shell pod
  image is fully qualified for mirrors. `Ctrl+s`, `Ctrl+g` and `Ctrl+b` are swallowed by Zellij's default preset.
- **k3s** (optional) and **MicroK8s** are installed but disabled: `sudo systemctl enable --now k3s` or
  `sudo systemctl enable --now snap.microk8s.daemon-kubelite`; k3s needs `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`.
  UFW allows the k3s API only from localhost and the pod and service networks.
- **argocd, kubeseal, tkn, k6, buildah, skopeo** are plain installs with completions where available.

### Security

- **ClamAV**: `clamav-daily-scan.timer` runs `clamscan` over `/home` and `/root` between 02:00 and 04:00 with low CPU and
  I/O priority, skips `.cache`, `.local/share/Trash`, `.git` and `.vscode-server` directories, stays on the local
  filesystem, and logs to `/var/log/clamav/daily-scan.log`; freshclam updates signatures. The on-access daemon is disabled.
- **Automatic updates**: unattended-upgrades for security and `-updates` origins plus the Mozilla repository, only on AC power.
- **Firewall**: UFW enabled with deny-incoming defaults and the k3s rules above (`sudo ufw status`).
- **lynis** is installed for manual audits: `sudo lynis audit system`.
- **Secrets**: gitleaks runs in the pre-commit hook; `gitleaks git` scans history, `gitleaks dir .` a tree.
- **Scanners**: `trivy fs .` (vulnerabilities, misconfigurations, secrets, licenses), `osv-scanner scan source -r .`
  (lockfiles against OSV), `opengrep scan --config p/default .` (SAST; `--config auto` would send the repository URL to the
  Semgrep registry), `syft scan dir:. -o spdx-json` (SBOM), `cosign verify`, `slsa-verifier verify-artifact`,
  `scorecard --repo=github.com/org/repo` (needs `GITHUB_TOKEN`, for example `GITHUB_TOKEN=$(gh auth token)`).
- **Supply chain**: mise refuses releases younger than 7 days (`minimum_release_age`), verifies checksums and
  attestations (`paranoid`), npm uses `min-release-age=7`, pipx `PIPX_COOLDOWN=7`, Go runs only the pinned toolchain
  (`GOTOOLCHAIN=local`). Details in [Security](security.md).
- **mkcert** creates locally trusted development certificates (`mkcert -install`; never share `rootCA-key.pem`).

### Code Quality

All core linters are on `PATH` and read project configuration; none is wired into the Git hooks except gitleaks and
gommitlint. Shipped defaults: `~/.config/devtools/formatting/java/eclipse-java-google-style.xml` and
`~/.config/devtools/linting/java/google_checks.xml` (Java pack).

| Area | Tools |
|------|-------|
| Shell | `shellcheck`, `shfmt -i 2` (also reads `.editorconfig`) |
| YAML, TOML, Markdown, text | `yamlfmt`, `taplo fmt --check`, `rumdl check`, `typos`, `vale` (needs a `.vale.ini`), `lychee` (links) |
| Containers and CI | `hadolint Dockerfile`, `actionlint` |
| Standards | `editorconfig-checker`, `publiccode-parser publiccode.yml`, `gommitlint validate` |
| Java pack | `checkstyle -c ~/.config/devtools/linting/java/google_checks.xml src/`, `google-java-format --replace`, `pmd check` |
| Go pack | `golangci-lint run ./...`, `staticcheck ./...`, `govulncheck ./...` |
| Node pack | `biome check .` |
| Rust pack | `cargo clippy`, `cargo fmt`, `cargo machete` |
| Tests and tasks | `bats`, `just` (`just --list` in a repository with a justfile) |

### Languages and mise

- **mise** manages every runtime and most CLI tools. The global config `~/.config/mise/config.toml` is generated by setup
  and regenerated on updates (the previous file is backed up); use a project `mise.toml` for versions that must survive
  that. Project version files (`.nvmrc`, `.python-version`) are ignored unless listed in
  `idiomatic_version_file_enable_tools`. `mise doctor` checks the installation; `mise ls` shows what is installed.
  A GitHub token is read from `gh auth login` to avoid API rate limits.
- **Packs** chosen during setup add their runtime and linters: Java (Temurin JDK, Maven, Gradle, PMD, Checkstyle,
  google-java-format, KeyStore Explorer; optional IntelliJ, JMC, DBeaver), Node (node, npm, biome), Python (python,
  pipx), Go (go, golangci-lint, staticcheck, govulncheck), Ruby (ruby and build libraries), Rust (rustc, cargo,
  cargo-machete). The system OpenJDK 25 serves desktop Java apps; mise provides the developer JDK.
- **Proxy and registries**: when the organization configuration sets them, setup writes `00-proxy.fish` and
  `00-registry.fish` (npm, pip, Go, Maven, Gradle, containers) and the `devbase-proxy` command toggles them.
  Java and Node trust the system CA store when custom certificates are installed.

### Desktop, Fonts and Browsers

- **Ghostty** (snap, not on WSL) with theme and font set by `devbase-theme` and `devbase-font`.
- **Nerd Fonts**: all four supported fonts are downloaded to `~/.cache/devbase/fonts/<version>/`, the chosen one
  (default Monaspace) is installed to `~/.local/share/fonts/`, and `devbase-font` switches between them for GNOME
  Terminal, Ghostty and VS Code without re-downloading. On WSL install the font on the Windows side.
  `fc-list | grep -i nerd` lists installed Nerd Fonts.
- **Firefox** comes from Mozilla's APT repository (not the snap) so PKCS#11 smart cards work;
  `devbase-firefox-opensc` registers OpenSC after the first launch. Chromium is installed as a snap or Flatpak.
- **Smart cards**: pcscd, OpenSC and cardpeek are installed on native Ubuntu but pcscd is disabled until needed
  (`sudo systemctl enable --now pcscd`). See [Smart Card Setup](smart-card-setup.md).
- **Citrix Workspace App**: `devbase-citrix` downloads the pinned release, verifies vendor checksums and package identity,
  and installs icaclient and ctxusb (native Ubuntu amd64 only).
- **Laptops and Windows disks**: TLP power management and dislocker (BitLocker volumes) are installed on native Ubuntu;
  BleachBit cleans caches and shreds files (`bleachbit --preview system.*` before `--clean`).
- **Windows Terminal** (WSL): `install-windows-terminal-themes` installs the DevBase color schemes once;
  `devbase-theme` then switches Windows Terminal with the other tools.

## Workflows

### Commit Safely

1. Stage your changes. The `pre-commit` hook scans the staged diff with gitleaks and blocks on a finding; fix it or, for a
   confirmed false positive, add a `gitleaks:allow` comment or a `.gitleaksignore` entry.
2. Write the message. `prepare-commit-msg` adds `Refs: PROJ-123` when the branch name carries an issue key.
   Use the Conventional Commits form (`type(scope): subject`) and `git cs` to add the sign-off.
3. The commit is signed with your SSH key (`git log --show-signature`). After the commit, gommitlint reports policy
   issues; fix them with `git commit --amend` before pushing.
4. Push with `git push` (`autoSetupRemote` creates the upstream). `git push-force` uses `--force-with-lease`.
   `git commit --no-verify` skips the hooks when you must.

### Scan a Project Before Release

```bash
gitleaks git                                   # secrets anywhere in history
trivy fs --severity HIGH,CRITICAL --exit-code 1 .   # vulnerabilities, misconfigurations, licenses
osv-scanner scan source -r .                   # dependency vulnerabilities from lockfiles
opengrep scan --config p/default --sarif -o opengrep.sarif .   # SAST; open the SARIF in VS Code
syft scan dir:. -o spdx-json > sbom.spdx.json  # SBOM to ship with the release
cosign sign-blob --yes sbom.spdx.json          # sign artifacts with Sigstore
```

Language packs add `govulncheck ./...`, `cargo audit` (install with `cargo install cargo-audit`) and `npm audit`.

### Container and Cluster Loop

```bash
podman build -t localhost/app:dev .            # buildah is used underneath; hadolint Dockerfile first
trivy image localhost/app:dev                  # scan the image before it leaves the machine
podman run --rm -p 8080:8080 localhost/app:dev
podman compose up                              # Compose through the mise provider
k9s                                            # browse the current context
kubeseal --format yaml < secret.yaml > sealed.yaml
argocd app sync my-app
```

For a local cluster enable k3s or MicroK8s as described above; k3s needs `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`.

### Keep the Workstation Current

- `devbase-update` fetches the latest DevBase release and reruns setup with your saved preferences, no questions asked;
  `--check` only reports, `--snooze 24` silences the shell-start prompt, `--ref <branch>` tests a branch.
- `devbase-reconfigure` reruns setup interactively when you want to change a preference.
- Rerunning setup regenerates managed files and mise tools; personal files and create-only configs are preserved
  ([Personalization](personalization.adoc)).
- `just devbase-install-verify` from the devbase-core checkout checks the installation after a reboot.
- `sudo lynis audit system` for a security audit, `sudo cat /var/log/clamav/daily-scan.log` for the last virus scan,
  `sudo unattended-upgrades --dry-run` to preview pending security updates.

## SSH Keys

Setup generates an ED25519 key (default name `id_ed25519_devbase`), loads it into the user `ssh-agent` service on
shell start, uses it for Git commit signing, and installs organization `known_hosts` entries. Personal hosts belong in
`~/.ssh/user.config`, which DevBase never modifies ([Personalization](personalization.adoc#ssh-configuration)).

```bash
ssh-keygen -t ed25519 -C "you@example.org" -f ~/.ssh/id_ed25519_work   # another key
ssh-add -l                                                            # keys in the agent
ssh-copy-id -i ~/.ssh/id_ed25519_devbase.pub user@host                # install on a server
ssh -T git@github.com                                                 # test a Git host
chmod 700 ~/.ssh; chmod 600 ~/.ssh/id_ed25519_devbase ~/.ssh/config   # permissions if something was copied in
```

If the agent is not running, the shell prints the `systemctl --user enable --now ssh-agent.service` command to start it.

## Proxy Configuration Reference

Different tools use different formats for proxy bypass lists. This reference helps configure proxies correctly across your development toolchain, especially important in corporate environments with proxy servers.

### Variable Naming: `http_proxy` vs `HTTP_PROXY`

| Tool/Language | `http_proxy` | `HTTP_PROXY` | `https_proxy` | `HTTPS_PROXY` | Precedence |
|---------------|--------------|--------------|---------------|---------------|------------|
| **curl** | ✅ | ❌ (security) | ✅ | ✅ | lowercase |
| **wget** | ✅ | ❌ | ✅ | ❌ | lowercase only |
| **Ruby** | ✅ | ✅ (warning) | ✅ | ✅ | lowercase |
| **Python** | ✅ | ✅ (if `REQUEST_METHOD` not set) | ✅ | ✅ | lowercase |
| **Go** | ✅ | ✅ | ✅ | ✅ | **UPPERCASE** |
| **Java** | N/A (uses system properties) | N/A | N/A | N/A | N/A |

**Always use lowercase `http_proxy` and `https_proxy`** - they are universally supported. Uppercase forms have inconsistent support and can cause issues.

---

### NO_PROXY / no_proxy Format

| Tool/Language | `no_proxy` | `NO_PROXY` | Suffix Match? | Leading `.` Stripped? | `*` = All? | CIDR? | Case Precedence |
|---------------|------------|------------|---------------|----------------------|------------|-------|-----------------|
| **curl** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | lowercase |
| **wget** | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | lowercase only |
| **Ruby** | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | lowercase |
| **Python** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | lowercase |
| **Go** | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | **UPPERCASE** |
| **Java** | N/A | N/A | ❌ (uses `http.nonProxyHosts`) | ❌ | ✅ | ❌ | N/A |

**Maven/Java: Uses `http.nonProxyHosts` system property with pipe separator**

- Format: `localhost|127.0.0.1|*.example.com`
- Wildcard: `*.example.com` matches subdomains, NOT bare domain
- **Does NOT** match suffixes automatically (unlike curl/wget/Ruby/Python/Go)

---

### Domain Pattern Behavior

Different tools interpret domain patterns differently:

| Pattern | curl | wget | Ruby | Python | Go | Java/Maven |
|---------|------|------|------|--------|-----|------------|
| `example.com` | Matches `example.com` and `*.example.com` | Matches `example.com` and `*.example.com` | Matches `example.com` and `*.example.com` | Matches `example.com` and `*.example.com` | Matches `example.com` and `*.example.com` | Exact match only |
| `.example.com` | Strips `.`, matches `example.com` and `*.example.com` | **Literal** match (`.example.com` only) | Strips `.`, matches `example.com` and `*.example.com` | Strips `.`, matches `example.com` and `*.example.com` | **Literal** match (`.example.com` only) | Not supported |
| `*.example.com` | Matches `sub.example.com` but NOT `example.com` | Matches `sub.example.com` but NOT `example.com` | Matches `sub.example.com` but NOT `example.com` | Matches `sub.example.com` but NOT `example.com` | Matches `sub.example.com` but NOT `example.com` | Matches `sub.example.com` but NOT `example.com` |

---

### Key Findings

- **Suffix matching works in all implementations EXCEPT Java/Maven** - most tools automatically match subdomains
- **Leading dot (`.`) behavior varies** - curl/Ruby/Python strip it, wget/Go treat it literally
- **wget is the most restrictive** - doesn't strip leading dots, doesn't support `NO_PROXY` (uppercase), doesn't support `*` to match all
- **Go prefers UPPERCASE** - this can cause issues in multi-language applications (see GitLab article below)

---

### Best Practices (Lowest Common Denominator)

1. **Always use lowercase** `http_proxy`, `https_proxy`, `no_proxy`
2. **For `no_proxy` entries:**
   - Use bare domains without leading dot: `example.com` (not `.example.com`)
   - All tools will match suffixes automatically (except Java)
   - Comma-separated list: `localhost,127.0.0.1,example.com,internal.net`
3. **For Java/Maven specifically:**
   - Use pipe-separated: `localhost|127.0.0.1|*.example.com|example.com`
   - Explicitly list both `*.example.com` AND `example.com` for full coverage
   - Java does NOT auto-match suffixes
4. **Avoid:**
   - Leading dots (`.example.com`) - inconsistent behavior
   - CIDR blocks - only Ruby and Go support them
   - IP addresses unless explicitly used by clients
   - Uppercase forms unless absolutely necessary (and make them identical to lowercase)

---

### Example Configuration

For shell tools (curl, wget, etc):

```bash
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080
export no_proxy=localhost,127.0.0.1,example.com,internal.net
```

For Java/Maven tools:

```bash
export JAVA_TOOL_OPTIONS="-Dhttp.proxyHost=proxy.example.com -Dhttp.proxyPort=8080 -Dhttp.nonProxyHosts=localhost|127.0.0.1|*.example.com|example.com|*.internal.net|internal.net"
```

---

### WSL Curl Configuration

**DevBase automatically configures curl for WSL environments** to prevent connection reuse issues commonly encountered with corporate proxies.

On WSL systems, DevBase creates a Fish shell alias that forces curl to use proxy-friendly settings:

```fish
alias curl='curl --no-keepalive --no-sessionid -H "Connection: close"'
```

**What this does:**

- `--no-keepalive` - Disables HTTP keep-alive (prevents connection reuse)
- `--no-sessionid` - Prevents SSL/TLS session ID reuse
- `-H "Connection: close"` - Explicitly requests connection closure after each request

**Why this is needed on WSL:**
Corporate proxies often have issues with persistent connections, connection pooling, and session reuse. These settings force curl to establish fresh connections for each request, improving reliability when working behind proxies.

**Location:** `~/.config/fish/conf.d/00-curl-proxy.fish` (auto-generated on WSL only)

**Note:** This alias only affects the Fish shell. If using bash, add the alias manually to `~/.bashrc`.

---

### Learn More

- [Maven Proxy Configuration](https://maven.apache.org/guides/mini/guide-proxies.html) - Official Maven proxy guide
- [Java Networking Properties](https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/doc-files/net-properties.html) - Java network system properties
- **[GitLab: Can we standardize NO_PROXY?](https://about.gitlab.com/blog/we-need-to-talk-no-proxy/)** - Detailed analysis of proxy inconsistencies across languages and real-world troubleshooting case study
