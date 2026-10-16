# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# Autoloadable on its own: the shell-start check consults it before
# devbase-update.fish has ever been loaded.
function __devbase_update_is_snoozed --description "True while devbase-update --snooze is in effect"
    set -l config_home "$HOME/.config"
    if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        set config_home "$XDG_CONFIG_HOME"
    end
    set -l snooze_file "$config_home/devbase/update-snooze"
    test -f "$snooze_file"; or return 1
    set -l until (cat "$snooze_file" 2>/dev/null)
    string match -qr '^[0-9]+$' -- "$until"; and test (date +%s) -lt "$until"
end
