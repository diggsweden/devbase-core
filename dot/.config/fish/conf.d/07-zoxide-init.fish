# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

# Initialize zoxide — a smarter cd. Provides `z` and `zi`.
# https://github.com/ajeetdsouza/zoxide
if type -q zoxide
    zoxide init fish | source
end
