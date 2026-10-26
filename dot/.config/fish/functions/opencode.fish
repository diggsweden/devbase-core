# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

function opencode --wraps opencode --description "Run OpenCode through nono-wrapper"
    if not command -q nono-wrapper
        printf '%s\n' 'opencode: nono-wrapper is required; OpenCode was not started.' \
            'Install nono-wrapper and its profiles: https://codefloe.com/itiquette/nono-wrapper' >&2
        return 127
    end
    command nono-wrapper opencode $argv
end
