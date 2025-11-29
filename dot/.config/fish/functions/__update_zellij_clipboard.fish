# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

function __update_zellij_clipboard --description "Auto-update Zellij clipboard config for current environment"
    set -l config_file "$HOME/.config/zellij/config.kdl"
    test -f "$config_file" || return 0

    set -l current_cmd (grep '^copy_command' "$config_file" 2>/dev/null | sed 's/copy_command "\(.*\)"/\1/')
    set -l needed_cmd

    if uname -r | grep -qi microsoft
        if test -x /mnt/c/Windows/System32/clip.exe
            set needed_cmd "/mnt/c/Windows/System32/clip.exe"
        else if type -q clip.exe
            set needed_cmd "clip.exe"
        end
    else if test "$XDG_SESSION_TYPE" = "wayland"; and type -q wl-copy
        set needed_cmd "wl-copy"
    else if type -q xclip
        set needed_cmd "xclip -selection clipboard"
    else if type -q xsel
        set needed_cmd "xsel --clipboard"
    else
        set needed_cmd "__smart_copy"
    end

    if test "$current_cmd" != "$needed_cmd"
        sed -i "s|^copy_command \".*\"|copy_command \"$needed_cmd\"|" "$config_file"
    end
end
