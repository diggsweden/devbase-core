# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# Brief: True when the running Ubuntu release is older than DevBase supports.
# Returns: 0 when Ubuntu is known and below the minimum, 1 otherwise.
# Notes: A non-Ubuntu or unreadable release returns 1 rather than guessing.
function __devbase_ubuntu_too_old --description "True when Ubuntu is older than DevBase supports"
    set -l min 26.04
    if set -q DEVBASE_MIN_UBUNTU_VERSION
        set min "$DEVBASE_MIN_UBUNTU_VERSION"
    end

    set -l os_release /etc/os-release
    if set -q DEVBASE_OS_RELEASE_FILE
        set os_release "$DEVBASE_OS_RELEASE_FILE"
    end

    test -r "$os_release"; or return 1

    set -l id (grep -m1 '^ID=' "$os_release" | cut -d= -f2 | tr -d '"')
    test "$id" = ubuntu; or return 1

    set -l release_version (grep -m1 '^VERSION_ID=' "$os_release" | cut -d= -f2 | tr -d '"')
    test -n "$release_version"; or return 1

    set -l current (string split . -- $release_version)
    set -l required (string split . -- $min)

    if test "$current[1]" -lt "$required[1]"
        return 0
    else if test "$current[1]" -gt "$required[1]"
        return 1
    end

    if test (count $current) -ge 2 -a (count $required) -ge 2
        test "$current[2]" -lt "$required[2]"; and return 0
    end

    return 1
end
