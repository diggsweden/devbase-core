# Devbase Core Tools Usage Guide

<!--
SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government

SPDX-License-Identifier: CC0-1.0
-->

This guide documents all tools in the devbase environment, including devbase-specific configurations and customizations.

**For personalizing your installation**, see [Personalization Guide](personalization.adoc) - includes theme switching, custom aliases, configuration file locations, and how to preserve your customizations across reinstalls.

## Table of Contents

- [Terminal & Shell Tools](#terminal--shell-tools)
  - [Fish Shell](#fish-shell)
  - [Ghostty (Terminal Emulator)](#ghostty-terminal-emulator---non-wsl-only)
  - [Nerd Fonts](#nerd-fonts---native-ubuntu-only)
  - [vifm (Vim File Manager)](#vifm-vim-file-manager)
  - [lf (List Files)](#lf-list-files)
  - [Starship (Cross-Shell Prompt)](#starship-cross-shell-prompt)
  - [Tree](#tree)
  - [Zellij (Terminal Multiplexer)](#zellij-terminal-multiplexer)
- [Development Tools](#development-tools)
  - [Bat (Better cat)](#bat-better-cat)
  - [btop](#btop)
  - [Delta (Git Diff Tool)](#delta-git-diff-tool)
  - [Eza (Modern ls)](#eza-modern-ls)
  - [FZF (Fuzzy Finder)](#fzf-fuzzy-finder)
  - [TLDR (Command Help)](#tldr-command-help)
  - [Git](#git)
  - [Git Cliff](#git-cliff)
  - [GitHub CLI (gh)](#github-cli-gh)
  - [GitLab CLI (glab)](#gitlab-cli-glab)
  - [jq (JSON Processor)](#jq-json-processor)
  - [JWT CLI](#jwt-cli)
  - [Lazygit](#lazygit)
  - [LazyVim](#lazyvim)
  - [Neovim](#neovim)
  - [Pandoc](#pandoc)
  - [Parallel](#parallel)
  - [PWGen](#pwgen)
  - [Ripgrep (rg)](#ripgrep-rg)
  - [fd (Find Alternative)](#fd-find-alternative)
  - [w3m](#w3m)
  - [yadm](#yadm)
  - [yq (YAML Processor)](#yq-yaml-processor)
- [Container & Kubernetes Tools](#container--kubernetes-tools)
  - [Argo CD CLI](#argo-cd-cli)
  - [Buildah](#buildah)
  - [Docker Compose](#docker-compose)
  - [K3s](#k3s)
  - [MicroK8s](#microk8s)
  - [K6](#k6)
  - [K9s](#k9s)
  - [Kubeseal](#kubeseal)
  - [OpenShift CLI (oc)](#openshift-cli-oc)
  - [Podman](#podman)
  - [Skopeo](#skopeo)
- [Java Development](#java-development)
  - [DBeaver](#dbeaver)
  - [JDK Mission Control](#jdk-mission-control)
  - [KeyStore Explorer](#keystore-explorer)
  - [Maven](#maven)
  - [VisualVM](#visualvm)
- [Code Quality & Security](#code-quality--security)
  - [Actionlint](#actionlint)
  - [Checkstyle](#checkstyle)
  - [ClamAV](#clamav)
  - [Conform](#conform)
  - [DNSUtils](#dnsutils)
  - [Gitleaks](#gitleaks)
  - [Hadolint](#hadolint)
  - [Lynis](#lynis)
  - [Mkcert](#mkcert)
  - [PMD](#pmd)
  - [Publiccode Parser](#publiccode-parser)
  - [RumDL](#rumdl)
  - [Scorecard](#scorecard)
  - [ShellCheck](#shellcheck)
  - [Shfmt](#shfmt)
  - [SLSA Verifier](#slsa-verifier)
  - [Syft](#syft)
  - [UFW (Uncomplicated Firewall)](#ufw-uncomplicated-firewall)
  - [GUFW (Graphical UFW)](#gufw-graphical-ufw)
  - [YamlFmt](#yamlfmt)
- [Build & Version Management](#build--version-management)
  - [Just](#just)
  - [Mise (Version Manager)](#mise-version-manager)
- [Programming Languages & Runtimes](#programming-languages--runtimes)
  - [Go](#go)
  - [Java (OpenJDK/Temurin)](#java-openjdktemurin)
  - [Node.js](#nodejs)
  - [Python](#python)
  - [Ruby](#ruby)
  - [Rust](#rust)
- [IDEs & Editors](#ides--editors)
  - [IntelliJ IDEA](#intellij-idea)
  - [VS Code Extensions](#vs-code-extensions)
- [Web Browsers](#web-browsers)
  - [Chromium](#chromium)
  - [Firefox](#firefox)
- [Additional Tools](#additional-tools)
  - [Dislocker (BitLocker Support)](#dislocker-bitlocker-support---non-wsl-only)
  - [TLP (Power Management)](#tlp-power-management---non-wsl-only)
  - [BleachBit](#bleachbit)
  - [Citrix Workspace App](#citrix-workspace-app-optional---non-wsl-only)
- [Proxy Configuration Reference](#proxy-configuration-reference)

---

## Terminal & Shell Tools

### Fish Shell

Interactive command line shell with autosuggestions that predict commands from your history as you type.
Displays syntax highlighting to show valid commands in real-time and provides tab completions without configuration.
Designed for interactive use rather than scripting, with simpler syntax than Bash for command-line work.
DevBase configures Fish with enhanced keybindings, FZF integration, and automatic tool initialization.

**Bash Compatibility Note:** Fish syntax differs in a few minor places from Bash, but bash scripts work fine if they have a proper shebang (`#!/bin/bash`) - which 99.5% of existing scripts have.
For specific Bash commands, simply run `bash -c "command"` or - just switch to Bash temporarily with `bash`.

#### Key Features & Commands

- **Accept full autosuggestion**:
  - `Alt+y` (devbase custom binding - ergonomic)
  - `→` (Right Arrow) or `Ctrl+f` (Fish defaults)
- **Clear screen**: `Ctrl+l`
- **Command history**: `↑/↓` arrows
- **Completion**: Tab
- **Exit shell**: `Ctrl+d` or `exit`
- **Search history**: `Ctrl+r`

#### Fish Shell Configuration

- **Config file location**: `~/.config/fish/config.fish`
- **Add to PATH**: `fish_add_path /path/to/directory`
- **Set environment variable**: `set -gx VARIABLE value`
- **Unset environment variable**: `set -e VARIABLE`
- **Create alias**: `alias ll='ls -la'`
- **Create function**:

  ```fish
  function myfunction
      echo "Hello from function"
  end
  ```

- **Save function**: `funcsave myfunction`
- **List functions**: `functions`

#### Useful Built-ins

- **Web-based configuration**: `fish_config`
- **Update completions**: `fish_update_completions`
- **Key bindings**: `fish_key_reader` (to identify key codes)

#### Fish Shell DevBase Custom Configuration

**Custom Keybindings:**

- `Alt+y` - Accept current autosuggestion (more ergonomic than Right Arrow)

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

**devbase-theme** - Set consistent themes across CLI tools:

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

**devbase-update** - Update DevBase core and re-run setup:

```bash
# Update to latest tag
devbase-update

# Update to a specific ref (branch or tag)
devbase-update --ref feat/misc-fixes
```

Note: when `--ref` is used, the persisted core repo at `~/.local/share/devbase/core` is pinned to that ref during the setup run. SHA refs are not supported.

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

**devbase-font** - Set fonts for terminals and editors:

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

**Automatic Environment Setup:**

- Starship prompt with Git integration
- Mise for version management (Node.js, Python, etc.)
- SSH agent auto-initialization
- Development-friendly PATH configuration

**Learn more**:

- Documentation: [Fish Shell Documentation](https://fishshell.com/docs/current/)
- Tutorial: [Fish for Bash Users](https://fishshell.com/docs/current/fish_for_bash_users.html)
- Man page: `man fish`
- Examples: `tldr fish`

---

### Ghostty (Terminal Emulator) - Non-WSL Only

Terminal emulator that uses GPU acceleration to render text faster than traditional terminals.
Handles large amounts of output efficiently and reduces input latency for responsive interaction.
Useful when working with logs, build output, or any high-volume terminal activity.
DevBase installs via snap and configures with system theme integration.

#### Ghostty Key Commands

- **Config file**: `~/.config/ghostty/config`
- **New tab**: `Ctrl+Shift+T`
- **New window**: `Ctrl+Shift+N`
- **Reload config**: `Ctrl+,`
- **Split pane**: `Ctrl+Shift+D`
- **Toggle fullscreen**: `F11`

**Learn more**:

- Documentation: [Ghostty Documentation](https://ghostty.org/docs/)
- Man page: `man ghostty`

---

### Nerd Fonts - Native Ubuntu Only

DevBase downloads **all 4 supported Nerd Fonts** to cache and installs your chosen font on native Ubuntu (not WSL). This provides proper rendering of icons, glyphs, and symbols in terminal applications.

**Available Fonts:**

- **JetBrains Mono** - Excellent readability for coding (default)
- **Fira Code** - Popular with extensive ligatures  
- **Cascadia Code** - Microsoft's font with Powerline support
- **Monaspace** - Superfamily with multiple styles

**What is a Nerd Font?**

Nerd Fonts are patched fonts that include 3,600+ glyphs from popular icon sets:

- Font Awesome, Devicons, Octicons (GitHub icons)
- Material Design Icons, Powerline symbols
- Weather icons, and many more...

**How Font Installation Works:**

1. **During Setup**: All 4 fonts downloaded to `~/.cache/devbase/fonts/v3.4.0/`
2. **Installation**: Your chosen font (set via `DEVBASE_FONT` variable) is installed to `~/.local/share/fonts/`
3. **Switching**: Use `devbase-font` command to switch fonts without re-downloading

**Switching Fonts:**

```fish
# Switch to a different font (auto-installs from cache)
devbase-font jetbrains-mono  # JetBrains Mono
devbase-font firacode        # Fira Code  
devbase-font cascadia-code   # Cascadia Code
devbase-font monaspace       # Monaspace
```

**Auto-Configuration:**

DevBase automatically configures the selected Nerd Font for:

1. **GNOME Terminal**: Sets default profile font
2. **Ghostty**: Updates `font-family` in config
3. **VS Code**: Updates `editor.fontFamily` setting

**Cache Location:**

Fonts are cached with version numbers for easy updates:

```text
~/.cache/devbase/fonts/
  └── v3.4.0/              # Nerd Fonts version
      ├── JetBrainsMono.zip
      ├── FiraCode.zip
      ├── CascadiaCode.zip
      └── Monaspace.zip
```

**WSL Note:**

On WSL, fonts must be installed on the Windows side (not in WSL). Install Nerd Fonts on Windows and configure your terminal emulator (Windows Terminal, ConEmu, etc.) to use them.

**Manual Font Configuration:**

```bash
# List installed Nerd Fonts
fc-list | grep -i "nerd"

# Check font is working (should show icons)
echo "        "  # Various nerd font icons
```

**Why This Matters:**

Modern CLI tools like `starship`, `eza`, `lf`, and `lazygit` use icons extensively. Without a Nerd Font, you'll see missing character boxes (□) instead of proper icons.

**Learn more**:

- [Nerd Fonts Homepage](https://www.nerdfonts.com/)
- [Monaspace by GitHub Next](https://github.com/githubnext/monaspace)

---

### vifm (Vim File Manager)

Two-pane file manager for the terminal that uses vim keybindings (hjkl for movement, dd to cut, yy to copy).
Lets you browse directories, preview files, and perform bulk operations without leaving the command line.
Efficient for managing files when you're already working in the terminal or prefer keyboard navigation.

#### vifm Key Commands

- **Command mode**: `:`
- **Create dir**: `:mkdir dirname`
- **Delete (cut)**: `dd`
- **Go to top/bottom**: `gg/G`
- **Help**: `:help`
- **Navigate**: `h/j/k/l` (vim keys)
- **Next/prev match**: `n/N`
- **Paste**: `p`
- **Quit**: `:q`
- **Rename**: `cw`
- **Search**: `/` (forward) `?` (backward)
- **Select file**: `t` or `Space`
- **Start**: `vifm`
- **Visual mode**: `v`
- **Yank (copy)**: `yy`

**Configuration**: `~/.config/vifm/vifmrc`

**Learn more**:

- Documentation: [vifm Documentation](https://vifm.info/)
- Man page: `man vifm`
- Examples: `tldr vifm`

---

### lf (List Files)

Minimalist terminal file manager similar to vifm but lighter and faster.
Uses vim-style keybindings for file operations with emphasis on speed and low memory usage.
Good alternative when you need quick file navigation without the overhead of a full-featured file manager.

#### lf Key Commands

- **Copy**: `y`
- **Create dir**: `:push %mkdir<space>`
- **Cut**: `d`
- **Go to top/bottom**: `gg/G`
- **Invert selection**: `v`
- **Navigate**: `h/j/k/l` (vim keys)
- **Next/prev**: `n/N`
- **Paste**: `p`
- **Quit**: `q`
- **Rename**: `:rename newname`
- **Search**: `/` (filter)
- **Select**: `Space`
- **Shell command**: `:!command` or `$command`
- **Start**: `lf`

**Configuration**: `~/.config/lf/lfrc`

**Learn more**:

- Documentation: [lf Documentation](https://github.com/gokcehan/lf)
- Man page: `man lf`
- Examples: `tldr lf`

---

### Starship (Cross-Shell Prompt)

Customizable shell prompt that displays relevant context like git branch, language versions, and command duration.
Shows information only when relevant (displays Node version only in Node projects, for example).
Replaces the default prompt with more useful information while remaining fast and responsive.

#### Starship Key Commands

- **Config file**: `~/.config/starship.toml`
- **Create config**: `starship config`
- **Explain prompt**: `starship explain`
- **Install to shell**: `starship init fish | source`
- **Print config**: `starship print-config`
- **Test config**: `starship timings`

#### Starship DevBase Custom Configuration

**Auto-Activation:**

- Automatically initialized in Fish
- Shows git status, tool versions, execution time
- Configurable via `~/.config/starship.toml`

**Learn more**:

- Documentation: [Starship Documentation](https://starship.rs/)
- Examples: `tldr starship`

---

### Tree

Lists directory contents recursively in a tree structure showing the hierarchy of files and folders.
Useful for understanding project organization or documenting folder structure.
Shows at a glance what files exist and how they're nested without manually navigating each directory.

#### Tree Key Commands

- **Basic tree**: `tree`
- **Directories only**: `tree -d`
- **Limit depth**: `tree -L 2`
- **Output to file**: `tree > structure.txt`
- **Pattern**: `tree -P "*.txt"`
- **Show all**: `tree -a`
- **Sizes**: `tree -h`

**Learn more**:

- Man page: `man tree`
- Examples: `tldr tree`

---

### Zellij (Terminal Multiplexer)

Divides a single terminal window into multiple panes and tabs, each running separate commands.
Sessions persist even if you close the terminal, letting you resume work exactly where you left off.
Eliminates the need for multiple terminal windows and preserves your workspace across reboots or SSH disconnects.
DevBase configures auto-start and custom keybindings for quick pane splitting.

#### Zellij Key Commands

- **Attach to session**: `zellij attach mysession` or `zellij a mysession`
- **Delete session**: `zellij delete-session mysession` or `zellij d mysession`
- **List sessions**: `zellij list-sessions` or `zellij ls`
- **New session with name**: `zellij --session mysession` or `zellij -s mysession`
- **Start Zellij**: `zellij`

#### Inside Zellij (Default Mode)

- **Lock mode**: `Ctrl+g` (disable accidental input)
  - **Tip**: Hold `Shift` to override mouse handling and select text normally
- **Pane mode**: `Ctrl+p` (manage panes)
  - `n` - New pane
  - `d` - Down split
  - `r` - Right split
  - `x` - Close pane
  - `f` - Toggle fullscreen
  - `w` - Toggle floating pane
- **Tab mode**: `Ctrl+t` (manage tabs)
  - `n` - New tab
  - `1-9` - Switch to tab number
  - `r` - Rename tab
  - `x` - Close tab
- **Resize mode**: `Ctrl+n`
  - `h/j/k/l` or arrow keys - Resize panes
- **Scroll mode**: `Ctrl+s`
  - `j/k` or arrows - Scroll
  - `d/u` - Page down/up
- **Session mode**: `Ctrl+o`
  - `d` - Detach from session
- **Quit Zellij**: `Ctrl+q`

#### Zellij DevBase Custom Configuration

**Custom Keybindings:**

- **Alt+d**: New pane down (quick split)
- **Alt+r**: New pane right (quick split)

**Auto-Start:**
Controlled by environment variables:

- `DEVBASE_ZELLIJ_AUTOSTART=true` - Auto-start Zellij
- `ZELLIJ_AUTO_ATTACH=true` - Attach to existing session
- `ZELLIJ_AUTO_EXIT=true` - Exit shell when leaving Zellij
- Disabled in SSH sessions and Linux console

**Other Customizations:**

- **Copy**: Uses `__smart_copy` function for clipboard integration
- **Default shell**: Fish
- **Mouse mode**: Enabled
- **Theme**: Follows system theme

**Learn more**:

- Documentation: [Zellij Documentation](https://zellij.dev/documentation/)
- Examples: `tldr zellij`

---

## Development Tools

### Bat (Better cat)

Displays file contents with syntax highlighting and line numbers, similar to `cat` but more readable.
Automatically pipes long files through a pager and shows git diff indicators in the margin.
Makes reviewing code or logs in the terminal significantly easier than plain text output.
DevBase aliases `bat` to handle Ubuntu/Debian's `batcat` naming.

#### Bat Key Commands

- **List themes**: `bat --list-themes`
- **Paging**: `bat --paging=always file.txt`
- **Plain output**: `bat -p file.txt`
- **Show line numbers**: `bat -n file.txt`
- **Show non-printable**: `bat -A file.txt`
- **Specific language**: `bat -l python file`
- **Theme**: `bat --theme=TwoDark file.txt`
- **View file**: `bat file.txt`

#### Bat DevBase Custom Configuration

**Alias:**

- `bat` → `batcat` (Ubuntu/Debian package name)

**Learn more**:

- Documentation: [Bat Documentation](https://github.com/sharkdp/bat)
- Man page: `man bat`
- Examples: `tldr bat`

---

### btop

System monitor showing CPU, memory, disk, and network usage with graphs and process details.
Helps identify what's consuming resources when your system is slow or unresponsive.
More detailed and visually informative than traditional top or htop.

#### btop Key Commands

- **Filter**: `f`
- **Kill process**: `k`
- **Options menu**: `o`
- **Quit**: `q`
- **Sort**: `s`
- **Start**: `btop`
- **Tree view**: `t`

#### btop DevBase Custom Configuration

**Alias:**

- `top` → `btop`

**Learn more**:

- Documentation: [btop Documentation](https://github.com/aristocratos/btop)
- Man page: `man btop`

---

### Delta (Git Diff Tool)

Renders git diffs with syntax highlighting and improved readability compared to default git output.
Highlights specific character changes within lines, making it easier to spot exact modifications.
Integrates with git automatically to improve the display of `git diff` and `git log -p` output.
DevBase pre-configures git to use delta automatically for all diff and log commands.

#### Delta Key Commands

- **Line numbers**: `delta --line-numbers`
- **Side-by-side**: `delta --side-by-side`
- **Syntax themes**: `delta --list-syntax-themes`
- **Themes**: `delta --list-themes`
- **Use with git**: `git config core.pager delta` (pre-configured in devbase)

**Learn more**:

- Documentation: [Delta Documentation](https://dandavison.github.io/delta/)
- Man page: `man delta`
- Examples: `tldr delta`

---

### Eza (Modern ls)

Replacement for `ls` that adds colors, icons, and git status information to directory listings.
Shows file types, permissions, and modification status at a glance with visual indicators.
Makes browsing directories in the terminal more informative than standard ls output.
DevBase aliases `ls` to `eza --icons` for enhanced default listings.

#### Eza Key Commands

- **All files**: `eza -a`
- **Basic listing**: `eza`
- **Extended attributes**: `eza -l@`
- **Git status**: `eza --git -l`
- **Human readable sizes**: `eza -lh`
- **Icons**: `eza --icons`
- **Long format**: `eza -l`
- **Sort by modified**: `eza -l --sort=modified`
- **Tree view**: `eza --tree` or `eza -T`

#### Eza DevBase Custom Configuration

**Alias:**

- `ls` → `eza --icons`

**Learn more**:

- Documentation: [Eza Documentation](https://eza.rocks/)
- Man page: `man eza`
- Examples: `tldr eza`

---

### FZF (Fuzzy Finder)

Interactive filter that lets you search through lists (files, command history, processes) by typing partial matches.
Narrows down results as you type without needing exact text, using fuzzy matching algorithms.
Essential for quickly finding files or recalling commands when you remember only part of the name.
DevBase includes fzf.fish plugin with mnemonic keybindings like Ctrl+R for history search.

#### fzf Basic Usage

- **Find files**: `fzf`
- **Preview files**: `fzf --preview 'cat {}'`
- **Select multiple**: `fzf -m` (use Tab to select)
- **Search with query**: `fzf -q "searchterm"`

#### Key Bindings (fzf.fish plugin)

The [fzf.fish plugin](https://github.com/PatrickF1/fzf.fish) provides powerful fuzzy search capabilities with mnemonic keybindings:

- **Ctrl+R**: **Search History** - Search command history with syntax-highlighted preview
- **Ctrl+Alt+F**: **Search Directory** - Search files/directories recursively with preview (Tab to select multiple)
- **Ctrl+Alt+L**: **Search Git Log** - Search git commits with diff preview
- **Ctrl+Alt+S**: **Search Git Status** - Search modified/staged files with diff preview
- **Ctrl+Alt+P**: **Search Processes** - Search running processes (great for finding PIDs)
- **Ctrl+V**: **Search Variables** - Search shell variables with scope info

**Tips:**

- Press **Tab** to select multiple items in any search
- If your cursor is on a word when you trigger a search, that word seeds the query
- Selected directories get a trailing `/` - select one and hit Enter to cd into it
- All searches show helpful previews to find what you need faster
- **Note**: If using Zellij, press `Ctrl+g` (lock mode) first if `Ctrl+Alt+P` conflicts with pane switching

**Learn more**:

- Documentation: [FZF documentation](https://github.com/junegunn/fzf)
- Plugin docs: [fzf.fish documentation](https://github.com/PatrickF1/fzf.fish)
- Man page: `man fzf`
- Examples: `tldr fzf`

---

### TLDR (Command Help)

Shows practical examples of how to use command-line tools instead of full manual pages.
Provides common use cases and actual command syntax you can copy and adapt.
Faster than reading man pages when you just need to remember how to use a command.

#### TLDR Key Commands

- **Get help for a command**: `tldr command`
- **List all pages**: `tldr --list`
- **Search in page names**: `tldr --search "pattern"`
- **Show raw markdown**: `tldr --raw command`
- **Update cache**: `tldr --update`

#### Examples

```bash
tldr tar        # Quick examples for tar
tldr git commit # Git commit examples
tldr docker run # Docker run examples
tldr find       # Find command examples
```

**Note**: TLDR provides practical examples for thousands of commands, making it easier than reading man pages.

**Learn more**:

- Documentation: [TLDR Pages](https://tldr.sh/)
- Man page: `man tldr`

---

### Git

Distributed version control system that tracks changes to files over time through snapshots called commits.
Enables multiple developers to work on the same codebase simultaneously through branching and merging.
Essential for coordinating team development and maintaining project history.
DevBase configures SSH signing, Delta pager, and security-focused git hooks.

#### Git Key Commands

- **Check status**: `git status`
- **Clone repo**: `git clone <url>`
- **Commit changes**: `git commit -m "message"`
- **Create branch**: `git branch <name>`
- **Initialize repo**: `git init`
- **Merge branch**: `git merge <branch>`
- **Pull changes**: `git pull`
- **Push changes**: `git push`
- **Show changes**: `git diff`
- **Stage changes**: `git add <file>` or `git add .`
- **Switch branch**: `git switch <branch>`
- **View history**: `git log`

#### Git DevBase Custom Configuration

**Aliases:**

- `cs` → `commit --signoff`
- `retris` → `rebase -i --signoff --gpg-sign`
- `pull-re` → `pull --rebase`
- `push-force` → `push --force-with-lease`
- `gc-aggressive` → Aggressive garbage collection
- `date-now` → `commit --amend --date=now --no-edit`

**Features:**

- **Editor**: Neovim as default
- **Pager**: Delta with syntax highlighting
- **Diff**: Colored move detection
- **Merge**: diff3 conflict style
- **Signing**: SSH key signing (instead of GPG)
- **Branch**: Default to 'main' instead of 'master'
- **Push**: Simple push (current branch only)

**Delta Integration:**

- Side-by-side diffs enabled
- Navigate between sections with n/N
- Theme follows system theme setting
- Interactive diff filtering

**Git Hooks:**

DevBase provides minimal git hooks focused on security and workflow automation. Project-specific linting (shellcheck, hadolint, etc.) should be configured per-project.

- **pre-commit** - Runs before creating commits:
  - `01-secrets-scan.sh` - Scans staged files for secrets using gitleaks

- **post-commit** - Validates commit policy (non-blocking):
  - `01-conventional-commits.sh` - Enforces conventional commits via conform (only if `.conform.yaml` exists in repo)

- **prepare-commit-msg** - Prepares commit message:
  - `01-add-issue-ref.sh` - Auto-adds `Refs:` trailer from branch name (e.g., `JIRA-123`)

**Learn more**:

- Documentation: [Git Documentation](https://git-scm.com/doc)
- Man page: `man git`
- Examples: `tldr git`

---

### Git Cliff

Parses git commit messages to automatically generate a changelog file.
Organizes commits by type (features, fixes, breaking changes) based on conventional commit format.
Eliminates manual changelog maintenance by extracting release notes from commit history.

#### Git Cliff Key Commands

- **Generate changelog**: `git cliff`
- **Init config**: `git cliff init`
- **Output to file**: `git cliff -o CHANGELOG.md`
- **Specific tag range**: `git cliff v1.0.0..v2.0.0`
- **Unreleased changes**: `git cliff --unreleased`

**Learn more**:

- Documentation: [Git Cliff Documentation](https://git-cliff.org/)
- Man page: `man git-cliff`
- Examples: `tldr git-cliff`

---

### GitHub CLI (gh)

Interacts with GitHub repositories, pull requests, and issues directly from the command line.
Lets you create PRs, review code, manage issues, and run workflows without opening a web browser.
Integrates GitHub operations into your terminal workflow instead of switching to the web interface.

#### GitHub CLI Key Commands

- **Authenticate**: `gh auth login`
- **Check out PR**: `gh pr checkout 123`
- **Clone repo**: `gh repo clone owner/repo`
- **Create gist**: `gh gist create file.txt`
- **Create issue**: `gh issue create`
- **Create PR**: `gh pr create`
- **Create repo**: `gh repo create`
- **List issues**: `gh issue list`
- **List PRs**: `gh pr list`
- **Run workflow**: `gh workflow run`
- **View PR**: `gh pr view`

**Learn more**:

- Documentation: [GitHub CLI Documentation](https://cli.github.com/manual/)
- Man page: `man gh`
- Examples: `tldr gh`

---

### GitLab CLI (glab)

Manages GitLab merge requests, issues, and CI/CD pipelines from the command line.
Provides the same terminal-based workflow for GitLab that gh provides for GitHub.
Keeps you in the terminal for GitLab operations instead of switching to the web UI.

#### GitLab CLI Key Commands

- **Authenticate**: `glab auth login`
- **CI/CD status**: `glab pipeline status`
- **Clone repo**: `glab repo clone owner/repo`
- **Create issue**: `glab issue create`
- **Create MR**: `glab mr create`
- **List MRs**: `glab mr list`
- **Run pipeline**: `glab pipeline run`
- **View MR**: `glab mr view`
- **View pipeline**: `glab pipeline view`

**Learn more**:

- Documentation: [GitLab CLI Documentation](https://gitlab.com/gitlab-org/cli)
- Man page: `man glab`
- Examples: `tldr glab`

---

### jq (JSON Processor)

Parses and manipulates JSON from the command line using a query language.
Extracts specific fields, filters arrays, and transforms JSON structure without writing code.
Essential for working with API responses, configuration files, or any JSON data in scripts.

#### jq Key Commands

- **Array element**: `jq '.[0]' file.json`
- **Filter**: `jq '.[] | select(.age > 30)' file.json`
- **Get field**: `jq '.field' file.json`
- **Map**: `jq '.[] | {name, age}' file.json`
- **Pretty print**: `jq '.' file.json`
- **Raw output**: `jq -r '.field' file.json`

**Learn more**:

- Documentation: [jq Documentation](https://jqlang.github.io/jq/manual/)
- Man page: `man jq`
- Examples: `tldr jq`

---

### JWT CLI

Decodes JWT tokens to inspect their payload and verify signatures from the command line.
Useful for debugging authentication issues or examining access tokens during API development.
Eliminates the need for online JWT decoders when working with token-based authentication.

#### JWT CLI Key Commands

- **Decode token**: `jwt decode TOKEN`
- **Encode token**: `jwt encode --secret=secret '{"sub": "1234"}'`
- **Verify token**: `jwt verify --secret=secret TOKEN`

**Learn more**:

- Documentation: [JWT CLI Documentation](https://github.com/mike-engel/jwt-cli)
- Examples: `tldr jwt`

---

### Lazygit

Interactive terminal interface for git that shows branches, commits, and changes in visual panels.
Performs git operations through keyboard shortcuts and menus instead of memorizing complex commands.
Makes tasks like staging files, viewing diffs, and managing branches faster than command-line git.
DevBase configures automatic theme switching to match system preferences.

#### Lazygit Key Commands

- **Branch**: `b`
- **Commit**: `c`
- **Pull**: `p`
- **Push**: `P`
- **Quit**: `q`
- **Refresh**: `R`
- **Start**: `lazygit`
- **Stash**: `S`
- **Status**: `s` (in files panel)

#### Devbase Configuration

- **Theme**: Automatically follows system theme (light/dark)

**Learn more**:

- Documentation: [Lazygit Documentation](https://github.com/jesseduffield/lazygit)
- In-app help: Press `?` for keybindings
- Examples: `tldr lazygit`

---

### LazyVim

Preconfigured Neovim setup that includes LSP, completion, file navigation, and IDE features out of the box.
Turns Neovim into a fully functional code editor without manually configuring dozens of plugins.
Provides a modern development environment while keeping Neovim's modal editing and speed.
DevBase includes LazyVim as the default Neovim configuration.

#### Key Mappings (Leader key is usually Space)

- **Leader key**: `Space`
- **Find files**: `<leader>ff`
- **Find in files (grep)**: `<leader>fg`
- **Recent files**: `<leader>fr`
- **File explorer**: `<leader>e`
- **Buffers**: `<leader>fb`
- **Close buffer**: `<leader>bd`
- **Format file**: `<leader>cf`
- **LSP info**: `<leader>cl`
- **Lazy (plugin manager)**: `<leader>l`
- **Mason (LSP installer)**: `<leader>cm`
- **Terminal**: `<leader>ft` or `Ctrl+/`

**Note**: If using Zellij, press `Ctrl+g` (lock mode) first when Ctrl key combinations conflict with Zellij's pane/tab controls

#### Window Navigation

- **Navigate windows**: `Ctrl+h/j/k/l`
- **Resize windows**: `Ctrl+arrows`
- **Split horizontal**: `<leader>-`
- **Split vertical**: `<leader>|`

#### Code Navigation

- **Go to definition**: `gd`
- **Go to references**: `gr`
- **Go to implementation**: `gi`
- **Hover documentation**: `K`
- **Code actions**: `<leader>ca`
- **Rename symbol**: `<leader>cr`
- **Next/prev diagnostic**: `]d` / `[d`

#### Search & Replace

- **Search in buffer**: `/pattern`
- **Search & replace**: `:%s/old/new/g`
- **Clear search highlight**: `<leader>uh`

**Learn more**:

- Documentation: [LazyVim Documentation](https://www.lazyvim.org/)
- In-app help: Press `<leader>?` for keybindings

---

### Neovim

Text editor that extends Vim with built-in LSP support, asynchronous operations, and Lua configuration.
Offers modal editing (normal, insert, visual modes) for efficient text manipulation using keyboard only.
Highly extensible through plugins and provides the foundation for IDE-like features while staying lightweight.
DevBase configures Neovim with LazyVim distribution for immediate productivity.

#### Modes

- **Normal mode**: `Esc`
- **Insert mode**: `i` (before cursor), `a` (after cursor), `I` (start of line), `A` (end of line)
- **Visual mode**: `v` (character), `V` (line), `Ctrl+v` (block)
- **Command mode**: `:`
- **Replace mode**: `R`

#### Basic Movement

- **Character**: `h` (left), `j` (down), `k` (up), `l` (right)
- **Word**: `w` (next word), `b` (previous word), `e` (end of word)
- **Line**: `0` (start), `^` (first non-blank), `$` (end)
- **Screen**: `H` (top), `M` (middle), `L` (bottom)
- **File**: `gg` (start), `G` (end), `{line}G` (go to line)
- **Page**: `Ctrl+f` (forward), `Ctrl+b` (backward)
- **Half-page**: `Ctrl+d` (down), `Ctrl+u` (up)

#### Editing

- **Delete**: `x` (character), `dd` (line), `dw` (word), `d$` (to end of line)
- **Copy (yank)**: `yy` (line), `yw` (word), `y$` (to end of line)
- **Paste**: `p` (after), `P` (before)
- **Undo/Redo**: `u` (undo), `Ctrl+r` (redo)
- **Indent**: `>>` (indent), `<<` (outdent), `=` (auto-indent)
- **Join lines**: `J`
- **Change**: `c` (change), `cc` (change line), `cw` (change word)

#### File Operations

- **Save**: `:w`
- **Save and quit**: `:wq` or `ZZ`
- **Quit**: `:q`
- **Force quit**: `:q!`
- **Save as**: `:w filename`
- **Open file**: `:e filename`
- **Split open**: `:sp filename` (horizontal), `:vsp filename` (vertical)

#### Useful Commands

- **Substitute**: `:s/old/new/` (line), `:%s/old/new/g` (file)
- **Execute shell**: `:!command`
- **Read command output**: `:r !command`
- **Set option**: `:set number`, `:set nonumber`
- **Help**: `:help topic`
- **Macros**: `qa` (record to a), `q` (stop), `@a` (play), `@@` (repeat)

#### Neovim DevBase Custom Configuration

**Aliases:**

- `vi` → `nvim`
- `vim` → `nvim`
- `vimbare` → `nvim -u NONE -N` (Neovim without config)

**Learn more**:

- Documentation: [Neovim Documentation](https://neovim.io/doc/)
- Man page: `man nvim`
- Examples: `tldr nvim`

---

### Pandoc

Universal document converter that translates between markup formats like Markdown, HTML, LaTeX, DOCX, and PDF.
Lets you write documentation in one format (typically Markdown) and convert to whatever format you need.
Useful for generating multiple output types from a single source file or converting between formats.

#### Pandoc Key Commands

- **List formats**: `pandoc --list-input-formats`
- **Markdown to HTML**: `pandoc file.md -o file.html`
- **Markdown to PDF**: `pandoc file.md -o file.pdf`
- **With template**: `pandoc file.md --template=template.html -o output.html`

**Learn more**:

- Documentation: [Pandoc Documentation](https://pandoc.org/MANUAL.html)
- Man page: `man pandoc`
- Examples: `tldr pandoc`

---

### Parallel

Runs multiple shell commands simultaneously across CPU cores instead of sequentially.
Significantly speeds up batch operations by processing many items at once.
Useful for tasks like converting files, processing data, or running tests on multiple inputs.

#### Parallel Key Commands

- **Basic usage**: `parallel echo ::: A B C`
- **From file**: `parallel -a file.txt command`
- **Jobs**: `parallel -j 4 command ::: inputs`
- **Multiple inputs**: `parallel echo {1} {2} ::: A B ::: 1 2`
- **Progress**: `parallel --progress command ::: inputs`

**Learn more**:

- Documentation: [GNU Parallel Documentation](https://www.gnu.org/software/parallel/)
- Man page: `man parallel`
- Examples: `tldr parallel`

---

### PWGen

Creates random passwords with specified length and complexity requirements.
Generates strong passwords that are harder to crack than human-chosen passwords.
Quick way to create secure passwords from the command line without using a password manager.

#### PWGen Key Commands

- **Generate password**: `pwgen`
- **Include symbols**: `pwgen -y 16`
- **No ambiguous chars**: `pwgen -B 16`
- **One per line**: `pwgen -1 16 5`
- **Secure**: `pwgen -s 16`
- **Specific length**: `pwgen 16`

**Learn more**:

- Documentation: [PWGen Documentation](https://sourceforge.net/projects/pwgen/)
- Man page: `man pwgen`
- Examples: `tldr pwgen`

---

### Ripgrep (rg)

Searches directory trees for text patterns, optimized for speed and automatically skipping ignored files.
Respects .gitignore rules and binary files by default, focusing on source code.
Significantly faster than grep when searching large codebases, with better defaults for development work.
DevBase uses ripgrep as the primary search tool across all configurations.

#### Basic Search

- **Search for pattern**: `rg "pattern"`
- **Case-insensitive**: `rg -i "pattern"`
- **Search specific file type**: `rg -t py "pattern"`
- **Search specific files**: `rg "pattern" file1.txt file2.txt`
- **Search in directory**: `rg "pattern" /path/to/dir`

#### Advanced Options

- **Show only filenames**: `rg -l "pattern"`
- **Show files without matches**: `rg --files-without-match "pattern"`
- **Count matches**: `rg -c "pattern"`
- **Show context**: `rg -C 3 "pattern"` (3 lines before/after)
- **Show only match**: `rg -o "pattern"`
- **Fixed string (not regex)**: `rg -F "exact_string"`
- **Multiline search**: `rg -U "pattern.*\n.*continuation"`

#### File Filtering

- **Include files**: `rg "pattern" -g "*.rs"`
- **Exclude files**: `rg "pattern" -g "!*.min.js"`
- **Ignore case in globs**: `rg "pattern" --iglob "*.PDF"`
- **Search hidden files**: `rg --hidden "pattern"`
- **Search ignored files**: `rg --no-ignore "pattern"`
- **List file types**: `rg --type-list`

#### Replacement

- **Replace text**: `rg "pattern" --replace "replacement"`
- **Replace with regex groups**: `rg "(\w+)" --replace '$1_suffix'`

**Learn more**:

- Documentation: [Ripgrep User Guide](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md)
- Man page: `man rg`
- Examples: `tldr rg`

---

### fd (Find Alternative)

Finds files and directories with simpler syntax than traditional `find` command.
Searches quickly while respecting .gitignore rules and displaying colored output.
Easier to use than `find` for common tasks like searching by filename or extension.
DevBase integrates fd with fzf for interactive file selection.

#### Usage Examples

- **Find by name**: `fd "pattern"`
- **Find with extension**: `fd -e txt` (all .txt files)
- **Find directories only**: `fd -t d "pattern"`
- **Find files only**: `fd -t f "pattern"`
- **Find executables**: `fd -t x`
- **Find empty files**: `fd -t e`
- **Find symlinks**: `fd -t l`

#### Search Options

- **Case-insensitive**: `fd -i "pattern"`
- **Fixed string**: `fd -F "exact_name"`
- **Full path search**: `fd -p "path/pattern"`
- **Regex mode**: `fd "^[0-9]+\.txt$"`
- **Glob mode**: `fd -g "*.rs"`

#### Scope Control

- **Search hidden files**: `fd -H "pattern"`
- **Search ignored files**: `fd -I "pattern"`
- **No ignore at all**: `fd -u "pattern"` (or `--unrestricted`)
- **Max depth**: `fd --max-depth 3 "pattern"`
- **Specific directory**: `fd "pattern" /path/to/dir`
- **Exclude paths**: `fd -E "*.min.js" "pattern"`

#### Output & Actions

- **Absolute paths**: `fd -a "pattern"`
- **Execute command**: `fd -x command {} "pattern"`
- **Execute in parallel**: `fd -X command {} "pattern"`
- **Size filter**: `fd --size -1m` (files smaller than 1MB)
- **Changed within**: `fd --changed-within 2weeks`
- **Changed before**: `fd --changed-before "2023-01-01"`

#### Integration with Other Tools

```bash
# Open files in editor
fd -e rs | xargs nvim

# Delete all .bak files
fd -e bak -X rm

# Count lines in all Python files
fd -e py -X wc -l

# Interactive file selection with fzf
fd -t f | fzf
```

**Note**: fd is used by fzf.fish for fast directory searching (Ctrl+Alt+F).

**Learn more**:

- Documentation: [fd Documentation](https://github.com/sharkdp/fd)
- Man page: `man fd`
- Examples: `tldr fd`

---

### w3m

Text-based web browser for viewing websites and HTML files directly in the terminal.
Renders HTML content as formatted text with support for tables, frames, and basic CSS.
Useful for reading documentation, checking websites without a GUI, or viewing HTML files in SSH sessions.

#### w3m Key Commands

- **Open URL**: `w3m https://example.com`
- **Open local file**: `w3m file.html`
- **Quit**: `q` then `y`
- **Back**: `B`
- **Follow link**: `Enter` (on highlighted link)
- **Next link**: `Tab`
- **Previous link**: `Shift+Tab`
- **Scroll down**: `Space` or `j`
- **Scroll up**: `b` or `k`
- **Search**: `/` (forward) or `?` (backward)
- **Open new URL**: `U`
- **View source**: `\`
- **External browser**: `M` (opens link in GUI browser)
- **Help**: `H`

#### Common Usage

```bash
# Quick web lookup
w3m https://example.com

# Read man pages as HTML
man -H bash | w3m -T text/html

# Preview markdown
pandoc README.md | w3m -T text/html

# Check HTTP headers
w3m -dump_head https://example.com
```

**Learn more**:

- Man page: `man w3m`
- Examples: `tldr w3m`

---

### yadm

Tracks dotfiles (configuration files like .bashrc, .gitconfig) in a git repository for synchronization across machines.
Works like git but specifically designed for managing home directory configuration files.
Keeps your personal settings consistent across multiple computers and lets you version control your configurations.

#### yadm Key Commands

- **Add file**: `yadm add ~/.bashrc`
- **Bootstrap**: `yadm bootstrap`
- **Clone dotfiles**: `yadm clone https://github.com/user/dotfiles`
- **Commit**: `yadm commit -m "message"`
- **List files**: `yadm list -a`
- **Push**: `yadm push`
- **Status**: `yadm status`

**Learn more**:

- Documentation: [yadm Documentation](https://yadm.io/)
- Man page: `man yadm`
- Examples: `tldr yadm`

---

### yq (YAML Processor)

Parses and manipulates YAML files from the command line, like jq but for YAML format.
Extracts values, modifies configuration, and converts between YAML and JSON.
Essential for working with Kubernetes configs, CI/CD pipelines, or any YAML-based configuration.

#### yq Key Commands

- **Convert to JSON**: `yq -o json file.yaml`
- **Merge files**: `yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' file1.yaml file2.yaml`
- **Read value**: `yq '.field' file.yaml`
- **Update value**: `yq '.field = "value"' file.yaml`

**Learn more**:

- Documentation: [yq Documentation](https://mikefarah.gitbook.io/yq/)
- Man page: `man yq`
- Examples: `tldr yq`

---

## Container & Kubernetes Tools

### Argo CD CLI

Manages Argo CD applications that deploy Kubernetes resources from Git repositories.
Provides command-line access to sync applications, view deployment status, and manage GitOps workflows.
Integrates continuous deployment operations into terminal workflows instead of using the web UI.

#### Argo CD CLI Key Commands

- **Create app**: `argocd app create app-name`
- **Delete app**: `argocd app delete app-name`
- **Get app**: `argocd app get app-name`
- **Get app history**: `argocd app history app-name`
- **List apps**: `argocd app list`
- **Login**: `argocd login argocd.example.com`
- **Sync app**: `argocd app sync app-name`

**Learn more**:

- Documentation: [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- Examples: `tldr argocd`

---

### Buildah

Builds container images from Dockerfiles or from scratch without needing a running daemon.
Gives more control over image layers and can run without root privileges.
Alternative to Docker build that works in environments where running a daemon isn't possible.

#### Buildah Key Commands

- **Build from Dockerfile**: `buildah bud -t myimage .`
- **Commit**: `buildah commit container image`
- **From scratch**: `buildah from scratch`
- **List containers**: `buildah containers`
- **List images**: `buildah images`
- **Mount container**: `buildah mount container`
- **Run command**: `buildah run container -- command`

**Learn more**:

- Documentation: [Buildah Documentation](https://buildah.io/)
- Man page: `man buildah`
- Examples: `tldr buildah`

---

### Docker Compose

Defines multi-container applications in a YAML file and manages them as a single unit.
Starts, stops, and connects multiple containers together for development environments.
Simplifies running complex applications that need databases, caches, and other services running simultaneously.

#### Docker Compose Key Commands

- **Exec command**: `docker compose exec service_name command`
- **List services**: `docker compose ps`
- **Rebuild**: `docker compose build`
- **Scale service**: `docker compose up -d --scale web=3`
- **Start services**: `docker compose up -d`
- **Stop services**: `docker compose down`
- **View logs**: `docker compose logs -f`

**Learn more**:

- Documentation: [Docker Compose Documentation](https://docs.docker.com/compose/)
- Examples: `tldr docker-compose`

---

### K3s

Lightweight Kubernetes distribution that uses less memory and disk space than full Kubernetes.
Designed for resource-constrained environments like development machines, edge devices, or IoT.
Provides full Kubernetes functionality with a simpler installation process and smaller footprint.

#### K3s Key Commands

- **Apply manifest**: `k3s kubectl apply -f manifest.yaml`
- **Get config**: `cat /etc/rancher/k3s/k3s.yaml`
- **Get nodes**: `k3s kubectl get nodes`
- **Get pods**: `k3s kubectl get pods --all-namespaces`
- **Install**: `curl -sfL https://get.k3s.io | sh -`
- **Uninstall**: `k3s-uninstall.sh`

#### Enable/Disable K3s

K3s is **disabled by default** to avoid consuming system resources. Enable it when needed:

- **Enable and start**: `sudo systemctl enable --now k3s`
- **Disable and stop**: `sudo systemctl disable --now k3s`
- **Check status**: `sudo systemctl status k3s`
- **Stop temporarily**: `sudo systemctl stop k3s`
- **Start**: `sudo systemctl start k3s`

**Learn more**:

- Documentation: [K3s Documentation](https://docs.k3s.io/)
- Examples: `tldr k3s`

---

### MicroK8s

Lightweight Kubernetes distribution from Canonical that runs as a snap package.
Provides a minimal Kubernetes installation with optional addons for DNS, storage, and ingress.
Designed for local development, testing, and edge deployments with easy addon management.

#### MicroK8s Key Commands

- **Add user to group**: `sudo usermod -a -G microk8s $USER` (then logout/login)
- **Apply manifest**: `microk8s kubectl apply -f manifest.yaml`
- **Enable addon**: `microk8s enable dns storage ingress`
- **Get config**: `microk8s config`
- **Get nodes**: `microk8s kubectl get nodes`
- **Get pods**: `microk8s kubectl get pods --all-namespaces`
- **List addons**: `microk8s status`
- **Disable addon**: `microk8s disable dashboard`

#### Enable/Disable MicroK8s

MicroK8s is **disabled by default** to avoid consuming system resources. Enable it when needed:

- **Enable and start**: `sudo systemctl enable --now snap.microk8s.daemon-kubelite`
- **Disable and stop**: `sudo systemctl disable --now snap.microk8s.daemon-kubelite`
- **Check status**: `sudo systemctl status snap.microk8s.daemon-kubelite`
- **Stop temporarily**: `microk8s stop`
- **Start**: `microk8s start`

#### Common Addons

- **dns**: CoreDNS for cluster DNS resolution
- **storage**: Default storage class for persistent volumes
- **ingress**: NGINX ingress controller
- **dashboard**: Kubernetes web dashboard
- **registry**: Private container registry
- **metrics-server**: Resource metrics API

**Learn more**:

- Documentation: [MicroK8s Documentation](https://microk8s.io/docs)
- Addons: [MicroK8s Addons](https://microk8s.io/docs/addons)

---

### K6

Load testing tool that runs performance tests written in JavaScript.
Simulates user traffic to measure how your application performs under load.
Helps identify performance bottlenecks and verify that systems meet performance requirements.

#### K6 Key Commands

- **Cloud run**: `k6 cloud script.js`
- **Output metrics**: `k6 run --out json=results.json script.js`
- **Run test**: `k6 run script.js`
- **Specify VUs**: `k6 run --vus 10 --duration 30s script.js`

**Learn more**:

- Documentation: [K6 Documentation](https://k6.io/docs/)
- Examples: `tldr k6`

---

### K9s

Interactive terminal UI for managing Kubernetes clusters with real-time updates.
Navigate pods, deployments, logs, and other resources using keyboard shortcuts instead of kubectl commands.
Makes Kubernetes operations faster and more visual than typing kubectl commands repeatedly.

#### K9s Key Commands

- **Delete**: `ctrl+d`
- **Deployments**: `:dp`
- **Describe**: `d`
- **Edit**: `e`
- **Logs**: `l` (on selected pod)
- **Namespaces**: `:ns`
- **Pods**: `:po`
- **Quit**: `:q` or `ctrl+c`
- **Search**: `/`
- **Services**: `:svc`
- **Shell**: `s` (on selected pod)
- **Start**: `k9s`

**Learn more**:

- Documentation: [K9s Documentation](https://k9scli.io/)
- Examples: `tldr k9s`

---

### Kubeseal

Encrypts Kubernetes Secret resources so they can be safely stored in version control.
Works with Sealed Secrets controller to decrypt secrets only inside the cluster.
Enables storing sensitive configuration in Git repositories without exposing credentials.

#### Kubeseal Key Commands

- **Fetch cert**: `kubeseal --fetch-cert`
- **Re-encrypt**: `kubeseal --re-encrypt < sealed-secret.yaml`
- **Seal secret**: `kubeseal < secret.yaml > sealed-secret.yaml`
- **Validate**: `kubeseal --validate < sealed-secret.yaml`

**Learn more**:

- Documentation: [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
- Examples: `tldr kubeseal`

---

### OpenShift CLI (oc)

Command-line tool for managing OpenShift clusters, extending standard kubectl functionality.
Provides access to OpenShift-specific features like routes, builds, and deployments.
Works like kubectl but includes additional commands for OpenShift's enterprise features.

#### OpenShift CLI Key Commands

- **Debug pod**: `oc debug pod-name`
- **Deploy app**: `oc new-app image`
- **Get pods**: `oc get pods`
- **Get projects**: `oc get projects`
- **Get routes**: `oc get routes`
- **Login**: `oc login https://api.cluster.com`
- **New project**: `oc new-project myproject`
- **Port forward**: `oc port-forward pod 8080:8080`
- **Switch project**: `oc project myproject`
- **View logs**: `oc logs pod-name`

**Learn more**:

- Documentation: [OpenShift CLI Documentation](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- Man page: `man oc`
- Examples: `tldr oc`

---

### Podman

Container engine that runs containers without requiring a background daemon or root access.
Compatible with Docker commands and images but with a more secure architecture.
Drop-in replacement for Docker that eliminates the daemon and allows rootless containers.
DevBase aliases `docker` to `podman` for seamless transition.

#### Podman Key Commands

- **Build image**: `podman build -t name .`
- **Create pod**: `podman pod create --name mypod`
- **Exec into container**: `podman exec -it container_id /bin/bash`
- **Generate systemd**: `podman generate systemd container_name`
- **List containers**: `podman ps -a`
- **List images**: `podman images`
- **Remove container**: `podman rm container_id`
- **Remove image**: `podman rmi image_id`
- **Run container**: `podman run -it image`
- **View logs**: `podman logs container_id`

#### Podman DevBase Custom Configuration

**Alias:**

- `docker` → `podman` (Podman as Docker replacement)

**Learn more**:

- Documentation: [Podman Documentation](https://docs.podman.io/)
- Man page: `man podman`
- Examples: `tldr podman`

---

### Skopeo

Inspects and copies container images between registries without downloading them locally.
Works directly with registries to move or examine images without needing a daemon running.
Useful for migrating images between registries or inspecting remote images without pulling them.

#### Skopeo Key Commands

- **Copy image**: `skopeo copy docker://source docker://dest`
- **Delete image**: `skopeo delete docker://registry/image:tag`
- **Inspect image**: `skopeo inspect docker://image:tag`
- **List tags**: `skopeo list-tags docker://registry/image`
- **Sync images**: `skopeo sync --src docker --dest dir registry/image /path`

**Learn more**:

- Documentation: [Skopeo Documentation](https://github.com/containers/skopeo)
- Man page: `man skopeo`
- Examples: `tldr skopeo`

---

## Java Development

### DBeaver

Database GUI that connects to any database with a JDBC driver (PostgreSQL, MySQL, Oracle, etc.).
Provides visual database browsing, SQL editing, and data export/import capabilities.
Universal database client that works with multiple database types from one application.

#### DBeaver Key Commands

- **Commit**: `Ctrl+Alt+C`
- **Execute SQL**: `Ctrl+Enter`
- **Format SQL**: `Ctrl+Shift+F`
- **New connection**: `Ctrl+Shift+N`
- **Open SQL editor**: `F3`
- **Rollback**: `Ctrl+Alt+R`

**Learn more**:

- Documentation: [DBeaver Documentation](https://dbeaver.io/docs/)

---

### JDK Mission Control

Analyzes Java application performance through low-overhead flight recordings from the JVM.
Profiles CPU usage, memory allocation, and thread behavior without significantly impacting running applications.
Diagnoses production performance issues that can't be reproduced in development environments.

#### JDK Mission Control Key Commands

- **Analyze**: Open .jfr file
- **Connect to JVM**: File → Connect → Create New Connection
- **Start**: `jmc`
- **Start recording**: Start Flight Recording

**Learn more**:

- Documentation: [JMC Documentation](https://docs.oracle.com/en/java/java-components/jdk-mission-control/)

---

### KeyStore Explorer

GUI for managing Java keystores, certificates, and cryptographic keys.
Provides visual interface for operations that would require complex keytool command-line syntax.
Makes certificate management easier when working with Java applications requiring SSL/TLS.

#### KeyStore Explorer Key Commands

- **Create keystore**: File → New → JKS/PKCS#12
- **Generate keypair**: Generate → Generate Key Pair
- **Import certificate**: Tools → Import Trusted Certificate
- **Open keystore**: `kse keystore.jks`

**Learn more**:

- Documentation: [KeyStore Explorer Documentation](https://keystore-explorer.org/docs/)

---

### Maven

Build tool for Java projects that manages dependencies and standardizes the build process.
Uses a pom.xml file to declare dependencies which Maven automatically downloads from repositories.
Provides consistent project structure and build lifecycle across Java projects.

#### Maven Key Commands

- **Clean**: `mvn clean`
- **Compile**: `mvn compile`
- **Create project**: `mvn archetype:generate`
- **Dependencies**: `mvn dependency:tree`
- **Install**: `mvn install`
- **Package**: `mvn package`
- **Run**: `mvn exec:java`
- **Skip tests**: `mvn install -DskipTests`
- **Test**: `mvn test`

**Note**: For proxy configuration details, see the [Proxy Configuration Reference](#proxy-configuration-reference) section.

**Learn more**:

- Documentation: [Maven Documentation](https://maven.apache.org/guides/)
- Man page: `man mvn`
- Examples: `tldr mvn`

---

### VisualVM

Monitors and profiles running Java applications to identify performance problems.
Shows CPU usage, memory consumption, thread activity, and allows taking heap dumps.
Useful for diagnosing memory leaks, identifying slow methods, and understanding JVM behavior.

#### VisualVM Key Commands

- **Connect to process**: File → Add JMX Connection
- **CPU profiling**: Click "CPU" button when connected
- **Heap dump**: Click "Heap Dump" button
- **Memory profiling**: Click "Memory" button
- **Start**: `visualvm`
- **Thread dump**: Click "Thread Dump" button

**Learn more**:

- Documentation: [VisualVM Documentation](https://visualvm.github.io/documentation.html)

## Code Quality & Security

### Actionlint

Lints GitHub Actions workflow YAML files to find errors before pushing to GitHub.
Validates syntax, shell commands, and expression usage in workflow definitions.
Catches common mistakes locally instead of discovering them after triggering CI/CD runs.

#### Actionlint Key Commands

- **Format output**: `actionlint -format '{{.message}}'`
- **Lint workflows**: `actionlint`
- **Online check**: `actionlint -online`
- **Specific file**: `actionlint .github/workflows/ci.yml`

**Learn more**:

- Documentation: [Actionlint Documentation](https://github.com/rhysd/actionlint)
- Examples: `tldr actionlint`

---

### Checkstyle

Checks Java code against a set of coding standards and style rules.
Enforces consistent formatting, naming conventions, and best practices across a codebase.
Helps maintain code quality by catching style violations before code review.

#### Checkstyle Key Commands

- **Generate report**: `java -jar checkstyle.jar -c config.xml -f xml -o report.xml src/`
- **Run check**: `java -jar checkstyle.jar -c config.xml MyClass.java`

**Learn more**:

- Documentation: [Checkstyle Documentation](https://checkstyle.org/)

---

### ClamAV

Open-source antivirus engine that scans files for malware and viruses.
Detects threats using signature databases that are updated regularly.
Provides virus scanning on Linux systems for files, email attachments, and downloads.

#### ClamAV Key Commands

- **Daemon status**: `systemctl status clamav-daemon`
- **Infected only**: `clamscan -i /path`
- **Remove infected**: `clamscan --remove /path`
- **Scan directory**: `clamscan -r /path`
- **Scan file**: `clamscan file`
- **Update database**: `freshclam`

**Learn more**:

- Documentation: [ClamAV Documentation](https://www.clamav.net/documents)
- Man page: `man clamscan`
- Examples: `tldr clamscan`

---

### Conform

Validates git commits against conventional commit format and other repository policies.
Ensures commit messages follow a consistent structure (type, scope, description).
Enforces repository standards like required sign-offs or commit message length limits.

#### Conform Key Commands

- **Check commits**: `conform enforce`
- **Check specific range**: `conform enforce --from=HEAD~5`
- **Init config**: `conform init`
- **Version**: `conform version`

**Learn more**:

- Documentation: [Conform Documentation](https://github.com/siderolabs/conform)

---

### DNSUtils

Collection of DNS query tools (dig, nslookup, host) for troubleshooting name resolution.
Looks up IP addresses for domains, queries specific DNS record types, and traces DNS resolution.
Essential for diagnosing connectivity issues related to DNS configuration or propagation.

#### DNSUtils Key Commands

- **Dig query**: `dig example.com`
- **Host info**: `host example.com`
- **Lookup domain**: `nslookup example.com`
- **Query specific server**: `dig @8.8.8.8 example.com`
- **Reverse lookup**: `dig -x 8.8.8.8`
- **Trace DNS**: `dig +trace example.com`

**Learn more**:

- Man page: `man dig`, `man nslookup`, `man host`
- Examples: `tldr dig`

---

### Gitleaks

Scans git repositories for accidentally committed secrets like API keys, passwords, and tokens.
Detects hardcoded credentials in code and commit history using pattern matching.
Prevents sensitive data from being pushed to repositories where it could be exposed.
DevBase includes gitleaks in pre-commit hooks for automatic secret scanning of staged files.

#### Gitleaks Key Commands

- **Generate report**: `gitleaks detect --report=leaks.json`
- **Protect mode**: `gitleaks protect`
- **Scan repo**: `gitleaks detect`
- **Scan specific commit**: `gitleaks detect --commit=abc123`
- **Use config**: `gitleaks detect --config=.gitleaks.toml`

**Learn more**:

- Documentation: [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- Examples: `tldr gitleaks`

---

### Hadolint

Analyzes Dockerfiles for best practices, security issues, and common mistakes.
Checks for problems like missing version pins, inefficient layer construction, or deprecated commands.
Improves container image quality by catching Dockerfile issues before building.

#### Hadolint Key Commands

- **Format output**: `hadolint -f json Dockerfile`
- **Ignore rules**: `hadolint --ignore DL3008 Dockerfile`
- **Lint Dockerfile**: `hadolint Dockerfile`
- **Use config**: `hadolint -c .hadolint.yaml Dockerfile`

**Learn more**:

- Documentation: [Hadolint Documentation](https://github.com/hadolint/hadolint)
- Examples: `tldr hadolint`

---

### Lynis

Audits Linux systems for security vulnerabilities and configuration issues.
Scans system settings, services, and configurations to identify security weaknesses.
Provides hardening recommendations to improve system security posture.

#### Lynis Key Commands

- **Create report**: `sudo lynis audit system --report-file /tmp/report.txt`
- **Quick scan**: `sudo lynis audit system --quick`
- **Show warnings only**: `sudo lynis show warnings`
- **Specific test**: `sudo lynis audit system --tests "BOOT-5202"`
- **System audit**: `sudo lynis audit system`

**Learn more**:

- Documentation: [Lynis Documentation](https://cisofy.com/documentation/lynis/)
- Man page: `man lynis`
- Examples: `tldr lynis`

---

### Mkcert

Generates locally-trusted SSL/TLS certificates for development without browser warnings.
Installs a local certificate authority on your machine that your browser trusts.
Enables testing HTTPS locally without self-signed certificate errors or security warnings.

#### Mkcert Key Commands

- **Install CA** (one-time): `mkcert -install`
- **Create cert** (run from `~/development/devcerts/`):
  - `mkcert localhost 127.0.0.1`
  - `mkcert example.com "*.example.com"`
  - `mkcert -pkcs12 localhost` (for Java/Spring Boot)
- **Note**: mkcert creates files in current directory
- Documentation: [Mkcert GitHub](https://github.com/FiloSottile/mkcert)
- Man page: `man mkcert`
- Examples: `tldr mkcert`

---

### PMD

Static analysis tool that finds potential bugs, dead code, and inefficient patterns in source code.
Supports multiple languages and detects issues like unused variables, overly complex methods, or copy-paste duplication.
Catches code quality issues before they make it into production.

#### PMD Key Commands

- **Generate report**: `pmd check -d src/ -f html -r report.html`
- **List rules**: `pmd check -d src/ -R rulesets/java/quickstart.xml --show-suppressed`
- **Run analysis**: `pmd check -d src/ -R rulesets/java/quickstart.xml`

**Learn more**:

- Documentation: [PMD Documentation](https://docs.pmd-code.org/)

---

### Publiccode Parser

Validates publiccode.yml files that describe software projects developed for the public sector.
Checks compliance with the publiccode standard used by government agencies to catalog software.
Ensures metadata about public software projects is structured correctly for discovery and reuse.

#### Publiccode Parser Key Commands

- **Check version**: `publiccode-parser-go version`
- **Parse and output**: `publiccode-parser-go parse publiccode.yml`
- **Validate file**: `publiccode-parser-go validate publiccode.yml`

**Learn more**:

- Documentation: [Publiccode Parser Documentation](https://github.com/italia/publiccode-parser-go)

---

### RumDL

Downloads content from Riksutställningar (Swedish Travelling Exhibitions) museum databases.
Retrieves cultural heritage materials and exhibition data in bulk.
Specialized tool for accessing Swedish museum digital collections.

#### RumDL Key Commands

- **Download**: `rumdl download URL`
- **List formats**: `rumdl formats`
- **Specify output**: `rumdl download -o output.file URL`

**Learn more**:

- Documentation: [RumDL Documentation](https://github.com/rvben/rumdl)

---

### Scorecard

Evaluates open source projects against security best practices with an automated score.
Checks for things like signed releases, security policies, dependency updates, and code review practices.
Helps assess the security risk of using a particular open source dependency.

#### Scorecard Key Commands

- **Local repo**: `scorecard --local .`
- **Output format**: `scorecard --format=json --repo=url`
- **Run checks**: `scorecard --repo=github.com/owner/repo`
- **Specific checks**: `scorecard --checks=Branch-Protection,Code-Review`

**Learn more**:

- Documentation: [Scorecard Documentation](https://github.com/ossf/scorecard)

---

### ShellCheck

Analyzes shell scripts for common errors, portability issues, and bad practices.
Catches mistakes like unquoted variables, incorrect conditionals, or deprecated syntax.
Prevents shell script bugs before execution and improves cross-platform compatibility.
DevBase includes ShellCheck in git hooks for automatic script validation.

#### ShellCheck Key Commands

- **Check script**: `shellcheck script.sh`
- **Exclude checks**: `shellcheck -e SC2086 script.sh`
- **Format output**: `shellcheck -f json script.sh`
- **Set shell**: `shellcheck -s bash script.sh`

**Learn more**:

- Documentation: [ShellCheck Documentation](https://www.shellcheck.net/)
- Man page: `man shellcheck`
- Examples: `tldr shellcheck`

---

### Shfmt

Automatically formats shell scripts with consistent indentation and style.
Standardizes shell script formatting similar to how gofmt works for Go.
Ensures readable, consistently formatted shell code without manual formatting effort.

#### Shfmt Key Commands

- **Check formatting**: `shfmt -d script.sh`
- **Format file**: `shfmt -w script.sh`
- **Indent with spaces**: `shfmt -i 2 script.sh`
- **List files**: `shfmt -l .`

**Learn more**:

- Documentation: [Shfmt Documentation](https://github.com/mvdan/sh)
- Examples: `tldr shfmt`

---

### SLSA Verifier

Verifies that software artifacts were built from expected source code without tampering.
Checks cryptographic attestations that prove where and how an artifact was built.
Validates supply chain security by ensuring artifacts match their claimed provenance.

#### SLSA Verifier Key Commands

- **Source repo**: `slsa-verifier verify-artifact file --source-uri github.com/owner/repo`
- **Verify artifact**: `slsa-verifier verify-artifact file --provenance-path provenance.json`
- **Verify image**: `slsa-verifier verify-image image:tag`

**Learn more**:

- Documentation: [SLSA Verifier Documentation](https://github.com/slsa-framework/slsa-verifier)

---

### Syft

Generates a Software Bill of Materials (SBOM) listing all packages and dependencies in an image or directory.
Identifies what software components are included, their versions, and licenses.
Essential for security audits, vulnerability scanning, and license compliance tracking.

#### Syft Key Commands

- **Generate SBOM**: `syft packages dir:.`
- **Include licenses**: `syft packages dir:. --license`
- **Output formats**: `syft packages dir:. -o json`
- **Scan image**: `syft packages docker:image:tag`

**Learn more**:

- Documentation: [Syft Documentation](https://github.com/anchore/syft)
- Examples: `tldr syft`

---

### UFW (Uncomplicated Firewall)

Manages firewall rules with simple commands instead of complex iptables syntax.
Controls which network ports are open and which IP addresses can connect.
Makes basic firewall configuration accessible without learning iptables internals.

#### UFW Key Commands

- **Allow from IP**: `sudo ufw allow from 192.168.1.100`
- **Allow port**: `sudo ufw allow 22/tcp`
- **Delete rule**: `sudo ufw delete allow 80`
- **Deny port**: `sudo ufw deny 3306`
- **Enable**: `sudo ufw enable`
- **Reset**: `sudo ufw reset`
- **Status**: `sudo ufw status verbose`

**Learn more**:

- Documentation: [UFW Documentation](https://help.ubuntu.com/community/UFW)
- Man page: `man ufw`
- Examples: `tldr ufw`

---

### GUFW (Graphical UFW)

Graphical interface for UFW firewall that manages rules through a visual application.
Provides the same firewall functionality as UFW but with point-and-click rule management.
Easier for users who prefer GUI over command-line for configuring firewall settings.

#### GUFW Key Features

- **Start GUFW**: Launch from applications menu or run `gufw`
- **Enable/Disable Firewall**: Toggle switch in main window
- **Add Rule**: Click "+" button to add allow/deny rules
- **Preconfigured Profiles**: Home, Office, Public network profiles
- **Rule Management**: View, edit, and delete existing rules visually
- **Port Configuration**: Specify ports and protocols through dialogs
- **Advanced Options**: Configure logging, default policies, and rule ordering

#### Common Tasks

- **Allow a port**: Click "+", select "Simple", choose port and protocol
- **Allow an application**: Click "+", select "Preconfigured", choose app
- **Block incoming**: Set "Incoming" policy to "Deny" in main window
- **View logs**: Enable logging in preferences, view system logs

**Learn more**:

- Documentation: [GUFW Documentation](https://help.ubuntu.com/community/Gufw)
- Homepage: [GUFW Homepage](http://gufw.org/)

---

### YamlFmt

Automatically formats YAML files with consistent indentation and structure.
Standardizes YAML formatting across configuration files in a project.
Prevents formatting inconsistencies that can make YAML files harder to read or cause parsing issues.

#### YamlFmt Key Commands

- **Check only**: `yamlfmt -lint file.yaml`
- **Config file**: `yamlfmt -conf .yamlfmt`
- **Format directory**: `yamlfmt .`
- **Format file**: `yamlfmt file.yaml`

**Learn more**:

- Documentation: [YamlFmt Documentation](https://github.com/google/yamlfmt)

---

## Build & Version Management

### Just

Task runner that executes commands defined in a justfile, similar to Make but simpler.
Provides a way to document and run project-specific commands with dependencies.
Eliminates the need to remember complex command sequences by giving them simple names.

#### Just Key Commands

- **Choose recipe**: `just --choose`
- **Evaluate**: `just --evaluate`
- **List recipes**: `just --list`
- **Run recipe**: `just recipe-name`
- **Show recipe**: `just --show recipe-name`
- **Variables**: `just variable=value recipe`

**Learn more**:

- Documentation: [Just Documentation](https://just.systems/)
- Man page: `man just`
- Examples: `tldr just`

---

### Mise (Version Manager)

Manages different versions of programming languages and tools on a per-project basis.
Automatically switches to the correct Node, Python, or other tool version when entering a project directory.
Replaces language-specific version managers (nvm, rbenv, pyenv) with a single unified tool.
DevBase uses mise as the primary tool version manager across all environments.

#### Mise Key Commands

- **Current versions**: `mise current`
- **Install from .mise.toml**: `mise install`
- **Install tool**: `mise use node@20`
- **List installed**: `mise list`
- **Set global**: `mise use -g node@20`
- **Uninstall**: `mise uninstall node@18`
- **Update tools**: `mise upgrade`

#### Mise DevBase Custom Configuration

**Auto-Activation:**

- Automatically activates mise for version management
- Adds mise shims to PATH
- Manages tool versions per project

**Configuration:**

- **Experimental features**: Enabled
- **Legacy version files**: Disabled (.nvmrc, .python-version)
- **ASDF compatibility**: Disabled (native mode)
- **Parallel jobs**: 6 (configurable)
- **Auto-yes**: Enabled for automated installs
- **HTTP timeout**: 90s (for corporate proxies)
- **Pre-configured tools**: All devbase tools managed via mise
- **Backend support**: aqua, ubi, core plugins

**Learn more**:

- Documentation: [Mise Documentation](https://mise.jdx.dev/)
- Man page: `man mise`
- Examples: `tldr mise`

---

## Programming Languages & Runtimes

### Go

Compiled programming language with built-in concurrency support and static typing.
Compiles to standalone binaries without runtime dependencies, simplifying deployment.
Designed for building network services, CLI tools, and concurrent applications.

#### Go Key Commands

- **Build binary**: `go build`
- **Format code**: `go fmt ./...`
- **Get dependencies**: `go get package`
- **Install tool**: `go install tool@latest`
- **Module init**: `go mod init module-name`
- **Run program**: `go run main.go`
- **Test**: `go test ./...`
- **Tidy modules**: `go mod tidy`

**Learn more**:

- Documentation: [Go Documentation](https://go.dev/doc/)
- Examples: `tldr go`

---

### Java (OpenJDK/Temurin)

Object-oriented programming language that runs on the Java Virtual Machine (JVM).
Compiles to bytecode that runs on any platform with a JVM installed (write once, run anywhere).
Used extensively for enterprise applications, Android development, and backend services.
DevBase includes Temurin OpenJDK builds for optimal performance.

#### Java Key Commands

- **Classpath**: `java -cp lib/* Main`
- **Compile**: `javac Main.java`
- **Debug**: `java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005 Main`
- **Run**: `java Main`
- **Run JAR**: `java -jar app.jar`
- **Version**: `java --version`

**Learn more**:

- Documentation: [Java Documentation](https://docs.oracle.com/en/java/)
- Man page: `man java`
- Examples: `tldr java`

---

### Node.js

JavaScript runtime built on Chrome's V8 engine that executes JavaScript outside the browser.
Enables server-side JavaScript development with access to file systems, networking, and system resources.
Powers web servers, build tools, and CLI applications using JavaScript and the npm package ecosystem.

#### Node.js Key Commands

- **Check version**: `node --version`
- **Interactive shell**: `node`
- **NPX runner**: `npx package-name`
- **Package manager**: `npm install`, `npm run script`
- **Run script**: `node script.js`
- **Run with inspect**: `node --inspect script.js`

**Learn more**:

- Documentation: [Node.js Documentation](https://nodejs.org/docs/)
- Man page: `man node`
- Examples: `tldr node`

---

### Python

Interpreted programming language with emphasis on code readability and simplicity.
Used for web development, data analysis, automation, scientific computing, and scripting.
Features extensive standard library and third-party packages for virtually any domain.

#### Python Key Commands

- **Activate venv**: `source venv/bin/activate` (Fish: `source venv/bin/activate.fish`)
- **Freeze deps**: `pip freeze > requirements.txt`
- **Install package**: `pip install package`
- **Interactive shell**: `python`
- **Requirements**: `pip install -r requirements.txt`
- **Run module**: `python -m module`
- **Run script**: `python script.py`
- **Virtual environment**: `python -m venv venv`

**Learn more**:

- Documentation: [Python Documentation](https://docs.python.org/)
- Man page: `man python3`
- Examples: `tldr python`

---

### Ruby

Interpreted programming language designed for simplicity and productivity with elegant syntax.
Emphasizes convention over configuration and is widely used for web development via Rails framework.
Features powerful metaprogramming capabilities and a rich ecosystem of gems (libraries).

#### Ruby Key Commands

- **Check version**: `ruby --version`
- **Install gems**: `gem install gem_name`
- **Interactive shell**: `irb`
- **List installed gems**: `gem list`
- **Run script**: `ruby script.rb`
- **Update gems**: `gem update`
- **Bundle install**: `bundle install` (install dependencies from Gemfile)
- **Bundle exec**: `bundle exec command` (run command with bundled gems)

#### Bundler (Dependency Management)

- **Create Gemfile**: `bundle init`
- **Install dependencies**: `bundle install`
- **Update dependencies**: `bundle update`
- **Check outdated**: `bundle outdated`
- **Run with bundle**: `bundle exec ruby script.rb`

**Learn more**:

- Documentation: [Ruby Documentation](https://www.ruby-lang.org/en/documentation/)
- Man page: `man ruby`
- Examples: `tldr ruby`

---

### Rust

Systems programming language focused on safety, speed, and concurrency without garbage collection.
Prevents memory errors at compile time through ownership system and borrow checker.
Used for performance-critical applications, CLI tools, systems programming, and WebAssembly.

#### Rust Key Commands

- **Check version**: `rustc --version`, `cargo --version`
- **Create new project**: `cargo new project_name`
- **Create library**: `cargo new --lib lib_name`
- **Build project**: `cargo build` (debug), `cargo build --release` (optimized)
- **Run project**: `cargo run`
- **Run tests**: `cargo test`
- **Check code**: `cargo check` (faster than build, checks compilation)
- **Format code**: `cargo fmt`
- **Lint code**: `cargo clippy`
- **Update dependencies**: `cargo update`

#### Cargo (Package Manager)

- **Add dependency**: Edit `Cargo.toml` and run `cargo build`
- **Search crates**: `cargo search crate_name`
- **Install binary**: `cargo install crate_name`
- **List installed**: `cargo install --list`
- **Clean build**: `cargo clean`
- **Generate docs**: `cargo doc --open`
- **Benchmark**: `cargo bench`

#### Common Ecosystem Tools

- **rustfmt** - Code formatter (included with Rust)
- **clippy** - Linter for catching common mistakes (included)
- **rustup** - Rust toolchain installer (managed by mise)
- **cargo-edit** - `cargo install cargo-edit` for `cargo add` command
- **cargo-watch** - `cargo install cargo-watch` for auto-rebuild on file changes

**Learn more**:

- Documentation: [Rust Documentation](https://doc.rust-lang.org/)
- Cargo Book: [The Cargo Book](https://doc.rust-lang.org/cargo/)
- Examples: `tldr rustc`

---

## IDEs & Editors

### IntelliJ IDEA

Integrated development environment specialized for Java with advanced code analysis and refactoring.
Provides intelligent code completion, navigation, and debugging for Java projects.

#### IntelliJ IDEA Key Commands

- **Debug**: `Shift+F9`
- **Find action**: `Ctrl+Shift+A`
- **Find usages**: `Alt+F7`
- **Generate code**: `Alt+Insert`
- **Go to declaration**: `Ctrl+B`
- **Open project**: `idea .`
- **Refactor**: `Ctrl+Alt+Shift+T`
- **Run**: `Shift+F10`
- **Search everywhere**: `Shift Shift`

**Learn more**:

- Documentation: [IntelliJ IDEA Documentation](https://www.jetbrains.com/idea/documentation/)

---

### VS Code Extensions

Curated set of Visual Studio Code extensions for common development tasks.
Adds language support, linting, formatting, and debugging capabilities to VS Code.
Pre-selected extensions that work well together for DevBase development workflows.

#### Extension Pack Mapping

Extensions are organized by language pack. Core extensions are always installed when VS Code extensions are enabled. Pack-specific extensions are only installed when that language pack is selected.

**Core** (always installed):

- [YAML](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml) - YAML language support with schema validation
- [SonarLint](https://marketplace.visualstudio.com/items?itemName=SonarSource.sonarlint-vscode) - Code quality and security analysis
- [SARIF Viewer](https://marketplace.visualstudio.com/items?itemName=MS-SarifVSCode.sarif-viewer) - View static analysis results
- [i18n Ally](https://marketplace.visualstudio.com/items?itemName=lokalise.i18n-ally) - Internationalization support
- [Material Icon Theme](https://marketplace.visualstudio.com/items?itemName=PKief.material-icon-theme) - File and folder icons
- [AsciiDoctor](https://marketplace.visualstudio.com/items?itemName=asciidoctor.asciidoctor-vscode) - AsciiDoc preview and editing
- [Neovim](https://marketplace.visualstudio.com/items?itemName=asvetliakov.vscode-neovim) - Vim keybindings (optional)
- [Everforest](https://marketplace.visualstudio.com/items?itemName=sainnhe.everforest) - Green-based color theme
- [Catppuccin](https://marketplace.visualstudio.com/items?itemName=catppuccin.catppuccin-vsc) - Pastel color theme
- [Tokyo Night](https://marketplace.visualstudio.com/items?itemName=enkia.tokyo-night) - Dark color theme
- [Gruvbox](https://marketplace.visualstudio.com/items?itemName=jdinhlife.gruvbox) - Retro groove color theme
- [Nord](https://marketplace.visualstudio.com/items?itemName=arcticicestudio.nord-visual-studio-code) - Arctic color theme
- [Dracula](https://marketplace.visualstudio.com/items?itemName=dracula-theme.theme-dracula) - Dark color theme
- [Solarized](https://marketplace.visualstudio.com/items?itemName=ryanolsonx.solarized) - Precision color theme

**Java** pack:

- [Extension Pack for Java](https://marketplace.visualstudio.com/items?itemName=vscjava.vscode-java-pack) - Complete Java development environment
- [Checkstyle](https://marketplace.visualstudio.com/items?itemName=shengchen.vscode-checkstyle) - Java code style checker

**Node** pack:

- [ESLint](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint) - JavaScript/TypeScript linting
- [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode) - Code formatter
- [Tailwind CSS IntelliSense](https://marketplace.visualstudio.com/items?itemName=bradlc.vscode-tailwindcss) - Tailwind CSS autocomplete
- [Volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar) - Vue.js language support

**Python**, **Go**, **Ruby**, **Rust** packs: No additional VS Code extensions.

> **Note**: If you don't select the Node pack, ESLint and Prettier extensions won't be installed since they require Node.js runtime.

#### Installing Extensions

Extensions are not installed during DevBase setup. After setup completes, use the convenience function:

```bash
# Install extensions based on your selected language packs
devbase-vscode-extensions

# List extensions that would be installed
devbase-vscode-extensions --list

# Preview installation without installing
devbase-vscode-extensions --dry-run
```

The function reads your preferences from `~/.config/devbase/preferences.yaml` and installs:

- Core extensions (always)
- Pack-specific extensions (based on your selected language packs)

You can run this function anytime to install or update extensions.

#### Language Support

**Extension Pack for Java** ([vscjava.vscode-java-pack](https://marketplace.visualstudio.com/items?itemName=vscjava.vscode-java-pack)

- Complete Java development environment including debugging, testing, and Maven/Gradle support.
- Bundles Language Support, Debugger, Test Runner, Maven, Project Manager, and IntelliCode.
- Essential for Java development with syntax highlighting, code completion, and refactoring.

**Volar** ([Vue.volar](https://marketplace.visualstudio.com/items?itemName=Vue.volar)

- Official Vue.js language support with TypeScript integration.
- Provides template type checking, component intelligence, and auto-imports.
- Required for Vue 3 development, replaces legacy Vetur extension.

**YAML** ([redhat.vscode-yaml](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

- YAML language support with schema validation and auto-completion.
- Validates Kubernetes manifests, CI/CD configs, and other YAML files.
- Detects common YAML syntax errors like indentation and type mismatches.

#### Code Quality & Formatting

**ESLint** ([dbaeumer.vscode-eslint](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint)

- Integrates ESLint JavaScript linter into VS Code for real-time error detection.
- Shows linting errors inline and provides automatic fixes for many issues.
- Enforces code style and catches common JavaScript/TypeScript mistakes.

**Prettier** ([esbenp.prettier-vscode](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)

- Opinionated code formatter supporting JavaScript, TypeScript, CSS, JSON, and more.
- Automatically formats code on save to maintain consistent style across projects.
- Works alongside ESLint for comprehensive code quality management.

**Checkstyle** ([shengchen.vscode-checkstyle](https://marketplace.visualstudio.com/items?itemName=shengchen.vscode-checkstyle)

- Integrates Checkstyle Java code style checker into VS Code.
- Highlights style violations inline and provides quick fixes.
- Enforces Java coding standards configured in checkstyle.xml files.

**SonarLint** ([SonarSource.sonarlint-vscode](https://marketplace.visualstudio.com/items?itemName=SonarSource.sonarlint-vscode)

- Detects code quality issues and security vulnerabilities as you write code.
- Supports Java, JavaScript, TypeScript, Python, PHP, and more.
- Provides detailed explanations and fix suggestions for detected issues.

#### Utilities & Enhancements

**Tailwind CSS IntelliSense** ([bradlc.vscode-tailwindcss](https://marketplace.visualstudio.com/items?itemName=bradlc.vscode-tailwindcss)

- Auto-completion, syntax highlighting, and linting for Tailwind CSS classes.
- Shows color previews and CSS definitions on hover.
- Essential for Tailwind CSS development with class validation and suggestions.

**Neovim** ([asvetliakov.vscode-neovim](https://marketplace.visualstudio.com/items?itemName=asvetliakov.vscode-neovim)

- Embeds real Neovim instance for native Vim keybindings and modal editing.
- Provides authentic Vim experience with full init.vim/init.lua support.
- Faster and more accurate than VS Code's built-in Vim emulation.

**Material Icon Theme** ([PKief.material-icon-theme](https://marketplace.visualstudio.com/items?itemName=PKief.material-icon-theme)

- File and folder icons based on Material Design for better visual navigation.
- Instantly recognize file types by their distinctive icons in the explorer.
- Improves code organization visibility and reduces mental overhead.

**SARIF Viewer** ([MS-SarifVSCode.sarif-viewer](https://marketplace.visualstudio.com/items?itemName=MS-SarifVSCode.sarif-viewer)

- Views Static Analysis Results Interchange Format (SARIF) files from security scanners.
- Displays results from tools like CodeQL, Semgrep, and other static analyzers.
- Navigates to source locations and provides detailed vulnerability information.

**Learn more**:

- VS Code Marketplace: [Visual Studio Code Marketplace](https://marketplace.visualstudio.com/vscode)
- Extension Docs: Each extension name above links to its marketplace page

---

## Web Browsers

### Chromium

Open-source web browser that forms the basis for Google Chrome, without Google-specific additions.
Provides modern web standards support and developer tools for testing web applications.
Useful for web development testing or as a privacy-focused alternative to Chrome.

#### Chromium Key Commands

- **App mode**: `chromium --app=https://example.com`
- **Disable plugins**: `chromium --disable-plugins`
- **Incognito**: `chromium --incognito`
- **Open**: `chromium`
- **User data dir**: `chromium --user-data-dir=/path`

**Learn more**:

- Documentation: [Chromium Documentation](https://www.chromium.org/developers/how-tos/)
- Man page: `man chromium`
- Examples: `tldr chromium`

---

### Firefox

Open-source web browser with strong privacy protections and comprehensive developer tools.
Independent rendering engine (not Chromium-based) useful for cross-browser testing.
Provides built-in developer tools for debugging, profiling, and testing web applications.

DevBase installs Firefox from Mozilla's official APT repository (not Ubuntu's snap package) for full smart card/PKCS#11 support.

#### Firefox Key Commands

- **New instance**: `firefox --new-instance`
- **Open**: `firefox`
- **Private window**: `firefox --private-window`
- **Profile manager**: `firefox -P`
- **Safe mode**: `firefox --safe-mode`

#### Smart Card Support

Firefox is configured to use OpenSC for smart card authentication (non-WSL only).

**devbase-firefox-opensc** - Configure Firefox for smart card support:

```bash
devbase-firefox-opensc  # Configure OpenSC PKCS#11 module
```

This command:

- Adds OpenSC PKCS#11 module to Firefox's security devices
- Enables smart card authentication for websites requiring client certificates
- Requires `pcscd` service running: `sudo systemctl enable --now pcscd`

**Note**: If Firefox was just installed, launch it once to create a profile, then run `devbase-firefox-opensc`.

To verify smart card is detected:

1. Insert your smart card
2. Open Firefox → Settings → Privacy & Security → Security Devices
3. You should see "OpenSC" with your card reader listed

**Learn more**:

- Documentation: [Firefox Documentation](https://developer.mozilla.org/en-US/docs/Mozilla/Firefox)
- Man page: `man firefox`
- Examples: `tldr firefox`

---

## Additional Tools

### Dislocker (BitLocker Support - Non-WSL Only)

Accesses BitLocker-encrypted Windows drives from Linux.
Mounts encrypted Windows partitions by decrypting them with a password or recovery key.
Enables reading and writing Windows drives from Ubuntu without booting into Windows.
Automatically installed on native Ubuntu only (WSL accesses Windows drives directly).

#### Dislocker Key Commands

- **Mount BitLocker volume**:

  ```bash
  sudo dislocker /dev/sdXN -u -- /mnt/bitlocker
  sudo mount -o loop /mnt/bitlocker/dislocker-file /mnt/windows
  ```

- **Read-only mount**: Add `-r` flag
- **With password**: `sudo dislocker /dev/sdXN -uPASSWORD -- /mnt/bitlocker`
- **With recovery key**: `sudo dislocker /dev/sdXN -p RECOVERY-KEY -- /mnt/bitlocker`

**Learn more**:

- Documentation: [Dislocker Documentation](https://github.com/Aorimn/dislocker)
- Man page: `man dislocker`

---

### TLP (Power Management - Non-WSL Only)

Manages laptop power settings to extend battery life on Linux.
Automatically adjusts CPU frequency, disk spin-down, screen brightness, and peripheral power based on power source.
Optimizes battery usage without requiring manual configuration of power management settings.
Automatically installed on native Ubuntu laptops only (not needed in WSL).

#### TLP Key Commands

- **Battery status**: `sudo tlp-stat -b`
- **Check status**: `sudo tlp-stat -s`
- **Configuration**: `sudo tlp-stat -c`
- **Recalibrate battery**: `sudo tlp recalibrate`
- **Start TLP**: `sudo tlp start`

#### TLP Configuration

- **Config file**: `/etc/tlp.conf`
- **Enable at boot**: Automatic (systemd service)
- **AC vs Battery modes**: Auto-switches

**Learn more**:

- Documentation: [TLP Documentation](https://linrunner.de/tlp/)
- Man page: `man tlp`
- Examples: `tldr tlp`

---

### BleachBit

Removes unnecessary files and clears privacy-sensitive data from the system.
Frees disk space by deleting cached files, temporary files, cookies, and browser history.
Helps maintain privacy by securely wiping traces of computer usage across applications.

#### BleachBit Key Commands

- **Start GUI**: Launch from applications menu or run `bleachbit`
- **Command line**: `bleachbit --list` to see cleaners, `bleachbit --clean <cleaner>` to run
- **Preview deletions**: `bleachbit --preview <cleaner>` to see what will be deleted
- **Clean system**: `sudo bleachbit --clean system.*` for system-wide cleaning
- **Shred files**: `bleachbit --shred file.txt` to securely delete files

#### Common Cleaning Tasks

- **Browser data**: Cleaners for Firefox, Chrome, Chromium cache and history
- **System cache**: APT cache, thumbnail cache, temporary files
- **Application data**: Cache and logs from various Linux applications
- **Free space**: Overwrite free disk space to prevent file recovery

#### GUI Features

- **Preview mode**: Shows what will be deleted before cleaning
- **Cleaner selection**: Check boxes for different types of data to clean
- **Shred files/folders**: Right-click context menu integration for secure deletion
- **Wipe free space**: Overwrite unused disk space for privacy

**Learn more**:

- Documentation: [BleachBit Documentation](https://www.bleachbit.org/documentation)
- Homepage: [BleachBit](https://www.bleachbit.org/)

---

### Citrix Workspace App (Optional - Non-WSL Only)

Citrix Workspace App provides access to virtual desktops and applications hosted on Citrix infrastructure.
Not installed by default - use the `devbase-citrix` command to download and install when needed.
Supports smart card authentication when pcscd service is enabled.

#### Installing Citrix Workspace App

```fish
# Check available version
devbase-citrix --check

# Download and install
devbase-citrix
```

This will download and install:

- `icaclient` - Main Citrix Workspace App
- `ctxusb` - USB device redirection support

#### Smart Card Support

For smart card authentication with Citrix:

```bash
# Enable PC/SC smart card daemon
sudo systemctl enable --now pcscd
```

#### Citrix Key Commands

- **Check version**: `devbase-citrix --check`
- **Install**: `devbase-citrix`
- **Show help**: `devbase-citrix --help`

**Learn more**:

- Documentation: [Citrix Workspace App for Linux](https://docs.citrix.com/en-us/citrix-workspace-app-for-linux)
- Downloads: [Citrix Downloads](https://www.citrix.com/downloads/workspace-app/linux/)

---

## Themes

Terminal and editor themes configuration for consistent appearance.

### DevBase Theme System

Applies consistent color schemes across all terminal tools with a single command.
Changes themes for bat, delta, FZF, Neovim, K9s, Lazygit, Zellij, and terminal emulators simultaneously.
Maintains visual consistency across your development environment without configuring each tool separately.

```fish
# Switch to a different theme
devbase-theme catppuccin-mocha
devbase-theme everforest-light
devbase-theme gruvbox-dark

# See available themes
devbase-theme
```

Affects: bat, delta, btop, eza, FZF, K9s, Neovim, vifm, Lazygit, Zellij, Ghostty (native Ubuntu), Windows Terminal (WSL)

**WSL Users:** DevBase now automatically updates Windows Terminal color schemes!

- Run `install-windows-terminal-themes` once to install custom themes (10 themes, Solarized uses built-in)
- `devbase-theme` automatically changes Windows Terminal colors to match
- Changes apply immediately (no restart needed)
- Solarized themes use Windows Terminal's built-in versions

---

## SSH Keys

SSH keys provide secure, passwordless authentication to remote servers.

### SSH Key Management

Authenticates to remote servers and Git repositories using cryptographic key pairs instead of passwords.
Generates public/private key pairs where the private key stays on your machine and public key goes on servers.
More secure than passwords because keys can't be guessed or brute-forced, and different keys can be used for different services.

#### Generate SSH Key

```bash
# Generate new SSH key (ED25519 - modern standard, DevBase default)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Or RSA (if ED25519 not supported by legacy systems)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# With specific filename
ssh-keygen -t ed25519 -f ~/.ssh/mykey_ed25519
```

---

### Key Management

```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent (use your key name)
ssh-add ~/.ssh/id_ed25519_devbase
# or for ECDSA: ssh-add ~/.ssh/id_ecdsa_521_mycompany

# List keys in agent
ssh-add -l

# Remove all keys from agent
ssh-add -D

# Copy public key to clipboard (use your key name)
cat ~/.ssh/id_ed25519_devbase.pub | xclip -selection clipboard
```

---

### Copy Key to Server

```bash
# Using ssh-copy-id (recommended - automatically uses your default key)
ssh-copy-id user@hostname

# Manual method (use your key name)
cat ~/.ssh/id_ed25519_devbase.pub | ssh user@hostname 'cat >> ~/.ssh/authorized_keys'

# Specific port
ssh-copy-id -p 2222 user@hostname
```

---

### SSH Config

Create `~/.ssh/config` for connection shortcuts:

```text
Host myserver
    HostName example.com
    User myuser
    Port 22
    IdentityFile ~/.ssh/id_ed25519_devbase  # Use your key name

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_key  # Or use a separate key for GitHub

Host *
    AddKeysToAgent yes
```

---

### Permissions (Important!)

```bash
# Set correct permissions (replace with your key name)
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519_devbase  # private key
chmod 644 ~/.ssh/id_ed25519_devbase.pub  # public key
chmod 600 ~/.ssh/config
chmod 600 ~/.ssh/authorized_keys
```

---

### Test Connection

```bash
# Test SSH connection
ssh -T git@github.com

# Verbose mode for debugging
ssh -vvv user@hostname

# Use specific key
ssh -i ~/.ssh/specific_key user@hostname
```

---

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
