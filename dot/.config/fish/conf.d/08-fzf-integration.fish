# ~/.config/fish/conf.d/08-fzf-integration.fish
# FZF integration configuration for PatrickF1/fzf.fish plugin
# These settings enhance the plugin with custom preview and fd options

# fd/fdfind options - passed to fd when plugin searches directories
# --hidden: Show hidden files
# --follow: Follow symlinks
# --exclude .git: Don't show .git directories
if command -q fd || command -q fdfind
    set -gx fzf_fd_opts --hidden --follow --exclude .git
end

# Bat preview with line limit and toggle keybind
# Plugin variable: fzf_preview_file_cmd - Custom file preview command
# Plugin variable: fzf_directory_opts - Extra options for directory search
if command -q bat
    # Use bat with line limit for performance
    set -gx fzf_preview_file_cmd "bat --style=numbers --color=always --line-range :500"
    # Add Ctrl-/ keybind to toggle preview window
    set -gx fzf_directory_opts "--bind 'ctrl-/:change-preview-window(down|hidden|)'"
else if command -q batcat
    # Debian/Ubuntu package bat as batcat
    set -gx fzf_preview_file_cmd "batcat --style=numbers --color=always --line-range :500"
    set -gx fzf_directory_opts "--bind 'ctrl-/:change-preview-window(down|hidden|)'"
end

# Note: FZF_DEFAULT_OPTS for theme colors is set in 00-environment.fish
# based on DEVBASE_THEME variable
