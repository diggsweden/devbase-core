# ~/.config/fish/conf.d/aliases.fish
# Aliases for command behavior changes
# Auto-sourced by Fish on startup

# Neovim as default editor
alias vi="nvim"
alias vim="nvim"
alias vimbare="nvim -u NONE -N"

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

# Better top (if btop is installed)
if type -q btop
    alias top="btop"
end

# TLDR pages (tlrc is the Rust client)
if type -q tlrc
    alias tldr="tlrc"
end

# Podman desktop (uncomment if using flatpak)
# alias podman-desktop='flatpak run io.podman_desktop.PodmanDesktop'