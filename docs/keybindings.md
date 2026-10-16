# DevBase Keybindings

One page for the keys that matter in a DevBase shell. Only DevBase additions and the collisions between tools are
DevBase-specific; everything else is the tool's default and `?` or `:help` inside the tool shows the full list.

## Fish

| Key | Action |
|-----|--------|
| `Alt+y` | Accept the autosuggestion (DevBase binding; `→` and `Ctrl+f` also work) |
| `Ctrl+r` | Fuzzy history search (fzf.fish) |
| `Ctrl+l` | Clear screen |
| `Tab` | Complete; DevBase generates completions for the mise-installed tools |

**Vim-style setup** (`fish_vi_key_bindings`, chosen during setup):

| Key | Action |
|-----|--------|
| `Esc` | Normal mode; the Starship prompt character turns from `>` into `<` |
| `i`, `a`, `I`, `A` | Back to insert mode |
| `h j k l`, `w b e`, `0 ^ $` | Move on the command line |
| `dd`, `cw`, `D`, `yy`, `p`, `u` | Edit the command line with Vim operators |
| `k` / `j` in normal mode | Previous / next history entry |
| `v` | Visual mode |
| `Ctrl+n` / `Ctrl+p` in insert mode | Next / previous history (swallowed by Zellij's default preset, see below) |

Switch for the current session with `fish_default_key_bindings` or `fish_vi_key_bindings`.
The permanent choice follows `EDITOR` at shell start ([Personalization](personalization.adoc#editor-preference)).

## fzf.fish

| Key | Search |
|-----|--------|
| `Ctrl+r` | Command history |
| `Ctrl+Alt+f` | Files and directories (eza preview, `Tab` selects several) |
| `Ctrl+Alt+l` | Git log (delta preview) |
| `Ctrl+Alt+s` | Git status (delta preview) |
| `Ctrl+Alt+p` | Processes |
| `Ctrl+v` | Shell variables |
| `Ctrl+/` | Toggle the preview window |

The word under the cursor seeds the query. A selected directory ends in `/`; press `Enter` on it to `cd`.

## Zellij

Default preset plus two DevBase bindings. Zellij is a prefix-less multiplexer, so its mode keys are taken from
the application underneath.

| Key | Action |
|-----|--------|
| `Alt+d` / `Alt+r` | New pane below / right (DevBase) |
| `Alt+n` | New pane |
| `Alt+h j k l` or `Alt+←↑↓→` | Move focus between panes |
| `Ctrl+p` | Pane mode (`n` new, `d`/`r` split, `x` close, `f` fullscreen, `w` floating) |
| `Ctrl+t` | Tab mode (`n` new, `1-9` switch, `r` rename, `x` close) |
| `Ctrl+n` | Resize mode (`h j k l`) |
| `Ctrl+s` | Scroll mode (`j k`, `d u`, `/` search, `e` edit scrollback in `$EDITOR`) |
| `Ctrl+o` | Session mode (`d` detach, `w` session manager) |
| `Ctrl+g` | Lock: all keys go to the application until `Ctrl+g` again |
| `Ctrl+q` | Quit Zellij |

**Collisions.** `Ctrl+p`, `Ctrl+n`, `Ctrl+o`, `Ctrl+s`, `Ctrl+h`, `Ctrl+t` and `Ctrl+g` are also Neovim, fish vi mode,
lazygit and k9s keys. Inside Zellij they never reach the application unless you press `Ctrl+g` first. Zellij's
"unlock-first" preset (`zellij setup --dump-config`, `keybinds` section) frees them; DevBase keeps the default preset
so panes stay one keystroke away.

## Neovim (LazyVim)

Leader is `Space`; `<leader>?` lists every mapping, `<leader>l` opens the plugin manager.

| Key | Action |
|-----|--------|
| `<leader>ff` / `<leader>fg` / `<leader>fr` | Find files / grep / recent files |
| `<leader>e` | File explorer |
| `<leader>fb` / `<leader>bd` | Buffers / close buffer |
| `<leader>cf` / `<leader>ca` / `<leader>cr` | Format / code action / rename |
| `gd` / `gr` / `K` | Definition / references / hover |
| `]d` / `[d` | Next / previous diagnostic |
| `Ctrl+h j k l` | Move between windows (needs Zellij lock) |
| `<leader>-` / `<leader>|` | Split below / right |
| `<leader>ft` or `Ctrl+/` | Terminal |
| `<leader>gg` | lazygit inside Neovim |

Plain Vim motions, operators and `:` commands apply as usual (`tldr nvim`, `:Tutor`).

## lazygit

| Key | Action |
|-----|--------|
| `?` | Keybindings for the focused panel |
| `Space` / `a` | Stage file / stage all |
| `c` / `A` | Commit / amend |
| `p` / `P` | Pull / push |
| `b` | Branch actions |
| `S` | Stash |
| `d` | Discard or delete |
| `e` | Edit in `$EDITOR` |
| `|` | Cycle diff renderers (DevBase ships delta) |
| `Ctrl+p` (patch), `Ctrl+s` (filter), `Ctrl+o` (copy) | Swallowed by Zellij unless locked |

## lf and vifm

| Key | lf | vifm |
|-----|----|------|
| Move | `h j k l`, `gg` / `G` | same |
| Select | `Space`, `v` invert | `t` or `Space`, `v` visual |
| Copy / cut / paste | `y` / `d` / `p` | `yy` / `dd` / `p` |
| Rename | `:rename name` | `cw` |
| Search | `/` filter, `n` / `N` | `/`, `?`, `n` / `N` |
| Open in `$EDITOR` | `e` | `Enter` on a file (`vicmd`) |
| Shell command | `$cmd` or `:!cmd` | `:!cmd` |
| Quit | `q` | `:q` |

## k9s

| Key | Action |
|-----|--------|
| `:` then a resource (`pods`, `deploy`, `svc`) | Switch view |
| `/` | Filter; `Esc` clears |
| `d` / `l` / `e` / `s` | Describe / logs / edit (`$EDITOR`) / shell |
| `Ctrl+d` | Delete |
| `0-9` | Namespaces |
| `?` | All keys; `Ctrl+s`, `Ctrl+g`, `Ctrl+b` need Zellij lock |

## btop

| Key | Action |
|-----|--------|
| `Esc` or `m` | Menu; `q` quits |
| `f` | Filter processes |
| `k` / `t` | Kill / terminate selected process |
| `+` / `-` | Expand or collapse process tree |
