# SPDX-FileCopyrightText: 2026 Digg - Agency for Digital Government
# SPDX-License-Identifier: MIT

# Handle both deb822 URIs (including continuation lines) and legacy deb lines.
# Match complete archive URLs, not third-party hosts or paths sharing a prefix.
function rewrite(line, result, matched, suffix) {
    result = ""
    while (match(line, /https?:\/\/(([[:alnum:]-]+\.)?archive\.ubuntu\.com|security\.ubuntu\.com)\/ubuntu\/?([ \t]|$)/)) {
        changed = 1
        matched = substr(line, RSTART, RLENGTH)
        suffix = matched ~ /[ \t]$/ ? substr(matched, length(matched), 1) : ""
        result = result substr(line, 1, RSTART - 1) mirror suffix
        line = substr(line, RSTART + RLENGTH)
    }
    return result line
}

/^[^ \t#][^:]*:/ { in_uris = ($0 ~ /^URIs:/) }
/^[ \t]*$/ { in_uris = 0 }
{
    if ($0 !~ /^[ \t]*#/ && (in_uris || /^[ \t]*deb(-src)?[ \t]/))
        print rewrite($0)
    else
        print
}
END { if (!changed) exit 3 }
