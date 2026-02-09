# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

#!/usr/bin/env fish
# WARNING: This file (00-aliases.fish) is managed by dev-base and will be OVERWRITTEN on reinstall
# 
# TO ADD YOUR OWN ALIASES:
# Create a file named 50-my-aliases.fish (or any number 50-99) in this directory
# Example: ~/.config/fish/conf.d/50-my-aliases.fish
# 
# Files numbered 50-99 are preserved during reinstallation
# See: https://github.com/org/devbase-core/blob/main/docs/configuration/personalization.adoc
#

# ~/.config/fish/conf.d/aliases.fish
# Aliases for command behavior changes
# Auto-sourced by Fish on startup

# Neovim as default editor (fallback to vim if missing)
if command -q nvim
    alias vi="nvim"
    alias vim="nvim"
    alias vimbare="nvim -u NONE -N"
else if command -q vim
    alias vi="vim"
    alias vim="vim"
    alias vimbare="vim -u NONE -N"
end

# Better ls with eza
alias ls="eza --icons"

# Container tools
alias docker="podman"

# Bat (only on Ubuntu/Debian where it's packaged as batcat)
if type -q batcat
    alias bat="batcat"
end

# Colorized output
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias egrep="egrep --color=auto"

# TLDR pages (tlrc is the Rust client)
if type -q tlrc
    alias tldr="tlrc"
end

# Podman desktop (uncomment if using flatpak)
# alias podman-desktop='flatpak run io.podman_desktop.PodmanDesktop'
