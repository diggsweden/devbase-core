# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

function __update_zellij_clipboard --description "Auto-update Zellij clipboard config for current environment"
    set -l config_file "$HOME/.config/zellij/config.kdl"
    test -f "$config_file" || return 0

    # Zellij spawns copy_command without a shell, so only real utilities work.
    # Without one the option stays unset and Zellij copies through OSC 52.
    set -l needed_cmd
    if uname -r | grep -qi microsoft
        if test -x /mnt/c/Windows/System32/clip.exe
            set needed_cmd "/mnt/c/Windows/System32/clip.exe"
        else if type -q clip.exe
            set needed_cmd "clip.exe"
        end
    else if test "$XDG_SESSION_TYPE" = wayland; and type -q wl-copy
        set needed_cmd wl-copy
    else if type -q xclip
        set needed_cmd "xclip -selection clipboard"
    else if type -q xsel
        set needed_cmd "xsel --clipboard"
    end

    # A commented line (written by setup or here) means "unset"; compare the
    # effective command so wording differences never cause rewrites.
    set -l current_line (string match -r '^(?://\s*)?copy_command.*$' <"$config_file")
    set -l current_cmd (string match -rg '^copy_command "(.*)"$' -- "$current_line")
    test "$current_cmd" = "$needed_cmd"; and return 0

    set -l wanted_line "copy_command \"$needed_cmd\""
    test -z "$needed_cmd"; and set wanted_line '// copy_command unset: no clipboard utility found, Zellij uses OSC 52'

    if test -z "$current_line"
        # No line at all (older or trimmed config): add one
        printf '%s\n' "$wanted_line" >>"$config_file"
        return 0
    end
    set -l escaped (string replace --all '|' '\\|' -- "$wanted_line")
    sed -i "s|^\(// *\)\?copy_command.*\$|$escaped|" "$config_file"
end
