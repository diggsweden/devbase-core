# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# Brief: Explain that further DevBase updates need a newer Ubuntu.
# Params: None
# Returns: 0 always
# Notes: Shown instead of an update prompt. Offering an update that setup.sh
#        will refuse leaves the core repo moved and nothing applied.
function __devbase_ubuntu_upgrade_notice --description "Explain the Ubuntu upgrade DevBase now needs"
    set -l min 26.04
    if set -q DEVBASE_MIN_UBUNTU_VERSION
        set min "$DEVBASE_MIN_UBUNTU_VERSION"
    end

    set -l os_release /etc/os-release
    if set -q DEVBASE_OS_RELEASE_FILE
        set os_release "$DEVBASE_OS_RELEASE_FILE"
    end

    set -l current unknown
    if test -r "$os_release"
        set -l release_version (grep -m1 '^VERSION_ID=' "$os_release" | cut -d= -f2 | tr -d '"')
        test -n "$release_version"; and set current "$release_version"
    end

    printf "\n"
    printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
    printf "%s  DevBase updates require Ubuntu %s%s\n" (set_color yellow) "$min" (set_color normal)
    printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
    printf "  You are on Ubuntu %s. Your current setup keeps working,\n" "$current"
    printf "  but new DevBase versions cannot be installed until you upgrade.\n"
    printf "\n"
    printf "  1. Back up your work: commit and push local repositories, and\n"
    printf "     copy anything you cannot lose off this machine.\n"
    printf "  2. Upgrade Ubuntu to %s or later.\n" "$min"
    printf "  3. Reboot, then run: %sdevbase-update%s\n" (set_color --bold) (set_color normal)
    printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" (set_color yellow) (set_color normal)
    printf "\n"
end
