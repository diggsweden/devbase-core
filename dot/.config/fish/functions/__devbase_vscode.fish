# SPDX-FileCopyrightText: 2025 Digg - Agency for Digital Government
#
# SPDX-License-Identifier: CC0-1.0

function __devbase_vscode_config_home --description "Get XDG config home"
    if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        echo "$XDG_CONFIG_HOME"
    else
        echo "$HOME/.config"
    end
end

function __devbase_vscode_is_wsl --description "Detect WSL environment"
    if set -q WSL_DISTRO_NAME; or set -q WSL_INTEROP
        return 0
    end

    if test -r /proc/version
        string match -iq "*microsoft*" -- (cat /proc/version)
        return $status
    end

    return 1
end

function __devbase_vscode_detect_wsl_distro --description "Detect WSL distro name"
    if set -q WSL_DISTRO_NAME; and test -n "$WSL_DISTRO_NAME"
        echo "$WSL_DISTRO_NAME"
        return 0
    end

    if test -r /etc/os-release
        set -l distro_name (string replace -r '^NAME="?(.*?)"?$' '$1' -- (grep '^NAME=' /etc/os-release 2>/dev/null | head -n 1))
        if test -n "$distro_name"
            echo "$distro_name"
            return 0
        end
    end

    echo "Ubuntu"
end

function __devbase_vscode_get_settings_path --description "Get VS Code settings file path"
    set -l machine_dir "$HOME/.vscode-server/data/Machine"
    if test -d "$machine_dir"
        echo "$machine_dir/settings.json"
        return 0
    end

    if __devbase_vscode_is_wsl; and test -d "$HOME/.vscode-server"
        mkdir -p "$machine_dir"
        echo "$machine_dir/settings.json"
        return 0
    end

    set -l config_home (__devbase_vscode_config_home)
    set -l code_dir "$config_home/Code"
    set -l user_dir "$code_dir/User"
    if test -d "$user_dir"; or test -d "$code_dir"
        echo "$user_dir/settings.json"
        return 0
    end

    return 1
end

function __devbase_vscode_find_remote_cli --description "Find VS Code remote CLI"
    for candidate in $HOME/.vscode-server/bin/*/bin/remote-cli/code
        if test -f "$candidate"
            echo "$candidate"
            return 0
        end
    end

    return 1
end

function __devbase_vscode_resolve_cli --description "Resolve VS Code CLI and remote target"
    if __devbase_vscode_is_wsl
        set -l remote_target "wsl+"(__devbase_vscode_detect_wsl_distro)
        set -l windows_code "/mnt/c/Program Files/Microsoft VS Code/bin/code"

        if test -x "$windows_code"; and set -q WSL_INTEROP
            echo "$windows_code"
            echo "$remote_target"
            return 0
        end

        set -l remote_cli (__devbase_vscode_find_remote_cli)
        if test -n "$remote_cli"
            echo "$remote_cli"
            echo ""
            return 0
        end

        if test -x "$windows_code"
            echo "$windows_code"
            echo "$remote_target"
            return 0
        end
    end

    if command -q code
        echo "code"
        echo ""
        return 0
    end

    return 1
end

function __devbase_vscode_merge_settings --description "Safely merge JSON into VS Code settings"
    set -l settings_file $argv[1]
    set -l update_json $argv[2]

    if test -z "$settings_file" -o -z "$update_json"
        return 1
    end

    if not command -q jq
        return 1
    end

    if not echo "$update_json" | jq -e 'type == "object"' >/dev/null 2>&1
        return 1
    end

    if test -f "$settings_file"
        if not jq -e 'type == "object"' "$settings_file" >/dev/null 2>&1
            return 2
        end

        set -l backup_file "$settings_file.bak."(date +%Y%m%d_%H%M%S)
        if not cp "$settings_file" "$backup_file"
            return 1
        end

        if jq -s '.[0] * .[1]' "$settings_file" (echo "$update_json" | psub) > "$settings_file.tmp"
            mv "$settings_file.tmp" "$settings_file"
            return 0
        end

        rm -f "$settings_file.tmp"
        return 1
    end

    mkdir -p (dirname "$settings_file")
    echo "$update_json" | jq '.' > "$settings_file"
end

function __devbase_vscode_describe_merge_status --description "Describe merge status code"
    set -l status_code $argv[1]

    switch $status_code
        case 2
            echo "VS Code settings.json is invalid JSON or not a JSON object; leaving it unchanged"
        case '*'
            echo "Failed to update VS Code settings; leaving existing file unchanged"
    end
end
