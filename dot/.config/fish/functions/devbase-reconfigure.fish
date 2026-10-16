# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# devbase-reconfigure - Rerun DevBase setup interactively with the saved
# preferences preselected, to change editor, theme, packs, tools or Git settings.
# devbase-update applies the saved preferences without asking.

function devbase-reconfigure --description "Change DevBase preferences by rerunning setup interactively"
    switch "$argv[1]"
        case --help -h
            echo "Usage: devbase-reconfigure [setup options]"
            echo ""
            echo "Reruns DevBase setup with your saved preferences preselected so you can"
            echo "change them. devbase-update reuses them without asking."
            echo ""
            echo "Options are passed to setup.sh (see 'setup.sh --help'), for example --tui=whiptail."
            return 0
    end

    set -l core_dir "$HOME/.local/share/devbase/core"
    if not test -f "$core_dir/setup.sh"
        printf "%s✗%s DevBase core not found at %s\n" (set_color red) (set_color normal) "$core_dir" >&2
        printf "  Run setup.sh from a devbase-core checkout first\n" >&2
        return 1
    end

    pushd "$core_dir" >/dev/null
    bash setup.sh $argv
    set -l setup_status $status
    popd >/dev/null
    return $setup_status
end
