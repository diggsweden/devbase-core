# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

function codex --wraps codex --description "Run Codex through nono-wrapper"
    if not command -q nono-wrapper
        printf '%s\n' 'codex: nono-wrapper is required; Codex was not started.' \
            'Install nono-wrapper and its profiles: https://codefloe.com/itiquette/nono-wrapper' >&2
        return 127
    end
    command nono-wrapper codex $argv
end
