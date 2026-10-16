# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# ~/.config/fish/conf.d/08-fzf-integration.fish
# FZF integration configuration for PatrickF1/fzf.fish plugin
# These settings enhance the plugin with directory search options

# fd/fdfind options - passed to fd when plugin searches directories
# --hidden: Show hidden files
# --follow: Follow symlinks
# --exclude .git: Don't show .git directories
if command -q fd || command -q fdfind
    set -gx fzf_fd_opts --hidden --follow --exclude .git
end

# Keep the plugin's argument-safe bat preview; custom commands use eval.
# Clear only the old DevBase export inherited from an already-running shell.
if contains -- "$fzf_preview_file_cmd" "bat --style=numbers --color=always --line-range :500" "batcat --style=numbers --color=always --line-range :500"
    set -eg fzf_preview_file_cmd
end
# Fish lists pass each option as a separate argument to fzf.
set -gx fzf_directory_opts --bind 'ctrl-/:change-preview-window(down|hidden|)'

# Directory previews with eza and git diffs with delta (both installed by DevBase)
if command -q eza
    set -gx fzf_preview_dir_cmd eza --all --color=always --icons=auto
end
if command -q delta
    set -gx fzf_diff_highlighter delta --paging=never --width=20
end

# Note: FZF_DEFAULT_OPTS for theme colors is set in 00-environment.fish
# based on DEVBASE_THEME variable
