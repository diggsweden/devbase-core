# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

function __devbase_update_check --description "Check for devbase updates on shell start"
    set -l core_dir "$HOME/.local/share/devbase/core"

    # Skip if core repo doesn't exist (not installed via new system)
    test -d "$core_dir/.git" || return 0

    # Check if devbase-update function exists
    if not functions -q devbase-update
        return 0
    end

    # Run update check (quick, just fetches and compares)
    set -l result (devbase-update --check 2>/dev/null)

    if test -n "$result"
        printf "\n"
        printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
        printf "%s  DevBase Update Available%s\n" (set_color yellow) (set_color normal)
        printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
        for line in $result
            printf "%s  • %s%s\n" (set_color yellow) "$line" (set_color normal)
        end
        printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
        printf "\n"

        # Drain any buffered stdin (e.g. accidental keypresses during slow output)
        while read -n 1 -t 0 2>/dev/null
        end

        read -P "Update now? [y/N] " -n 1 response
        printf "\n"

        if string match -qi 'y' -- $response
            devbase-update
        else
            printf "%sRun 'devbase-update' later to update.%s\n" (set_color --dim) (set_color normal)
        end
    end
end
