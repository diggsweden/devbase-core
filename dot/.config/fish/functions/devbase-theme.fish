function __devbase_theme_show_usage --description "Display theme usage information"
    printf "Usage: devbase-theme <name>\n"
    printf "\n"

    set -l current_theme (set -q DEVBASE_THEME; and echo $DEVBASE_THEME; or echo "everforest-dark")
    
    set -l theme_variant "dark"
    if __devbase_theme_is_light $current_theme
        set theme_variant "light"
    end
    
    printf "Current theme: "
    set_color green --bold
    printf "%s" "$current_theme"
    set_color normal
    printf " (%s)\n" "$theme_variant"

    printf "\nAvailable themes:\n"
    printf "  Everforest:  everforest-dark (default), everforest-light\n"
    printf "  Catppuccin:  catppuccin-mocha, catppuccin-latte\n"
    printf "  Tokyo Night: tokyonight-night, tokyonight-day\n"
    printf "  Gruvbox:     gruvbox-dark, gruvbox-light\n"
    printf "  Nord:        nord\n"
    printf "  Dracula:     dracula\n"
    printf "  Solarized:   solarized-dark, solarized-light\n"
end

function __devbase_theme_validate --description "Validate theme name"
    set -l theme_name $argv[1]
    set -l valid_themes everforest-dark everforest-light \
                        catppuccin-mocha catppuccin-latte \
                        tokyonight-night tokyonight-day \
                        gruvbox-dark gruvbox-light \
                        nord \
                        dracula \
                        solarized-dark solarized-light
    
    if not contains $theme_name $valid_themes
        printf "Unknown theme: %s\n" $theme_name
        __devbase_theme_show_usage
        return 1
    end
    return 0
end

function __devbase_theme_is_light --description "Check if theme is light variant"
    set -l theme_name $argv[1]
    if string match -q "*-light" $theme_name; or string match -q "*-latte" $theme_name; or string match -q "*-day" $theme_name
        return 0
    end
    return 1
end

function __devbase_theme_get_bat_theme
    set -l theme_name $argv[1]
    switch $theme_name
        case everforest-dark
            echo "Monokai Extended"
        case everforest-light
            echo "GitHub"
        case catppuccin-mocha
            echo "Dracula"
        case catppuccin-latte
            echo "OneHalfLight"
        case tokyonight-night
            echo "Visual Studio Dark+"
        case tokyonight-day
            echo "GitHub"
        case gruvbox-dark
            echo "gruvbox-dark"
        case gruvbox-light
            echo "gruvbox-light"
        case nord
            echo "Nord"
        case dracula
            echo "Dracula"
        case solarized-dark
            echo "Solarized (dark)"
        case solarized-light
            echo "Solarized (light)"
    end
end

function __devbase_theme_get_btop_theme
    set -l theme_name $argv[1]
    switch $theme_name
        case everforest-dark
            echo "everforest-dark-hard"
        case everforest-light
            echo "everforest-light-medium"
        case catppuccin-mocha
            echo "catppuccin_mocha"
        case catppuccin-latte
            echo "catppuccin_latte"
        case tokyonight-night
            echo "tokyo-night"
        case tokyonight-day
            echo "everforest-light-medium"
        case gruvbox-dark
            echo "gruvbox_dark"
        case gruvbox-light
            echo "gruvbox_light"
        case nord
            echo "nord"
        case dracula
            echo "dracula"
        case solarized-dark
            echo "solarized_dark"
        case solarized-light
            echo "solarized_light"
    end
end

function __devbase_theme_get_eza_theme
    set -l theme_name $argv[1]
    switch $theme_name
        case everforest-dark everforest-light
            echo "default.yml"
        case catppuccin-mocha catppuccin-latte
            echo "catppuccin.yml"
        case tokyonight-night tokyonight-day
            echo "tokyonight.yml"
        case gruvbox-dark
            echo "gruvbox-dark.yml"
        case gruvbox-light
            echo "gruvbox-light.yml"
        case nord
            echo "nord.yml"
        case dracula
            echo "dracula.yml"
        case solarized-dark
            echo "solarized-dark.yml"
        case solarized-light
            echo "solarized-light.yml"
    end
end

function __devbase_theme_get_k9s_skin
    set -l theme_name $argv[1]
    switch $theme_name
        case everforest-dark
            echo "everforest-dark"
        case everforest-light
            echo "everforest-light"
        case catppuccin-mocha
            echo "catppuccin-mocha"
        case catppuccin-latte
            echo "catppuccin-latte"
        case tokyonight-night
            echo "gruvbox-dark"
        case tokyonight-day
            echo "everforest-light"
        case gruvbox-dark
            echo "gruvbox-dark"
        case gruvbox-light
            echo "gruvbox-light"
        case nord
            echo "nord"
        case dracula
            echo "dracula"
        case solarized-dark
            echo "solarized-dark"
        case solarized-light
            echo "solarized-light"
    end
end

function __devbase_theme_get_zellij_theme
    set -l theme_name $argv[1]
    switch $theme_name
        case everforest-dark
            echo "everforest-dark"
        case everforest-light
            echo "everforest-light"
        case catppuccin-mocha
            echo "catppuccin-mocha"
        case catppuccin-latte
            echo "catppuccin-latte"
        case tokyonight-night
            echo "tokyo-night"
        case tokyonight-day
            echo "tokyo-day"
        case gruvbox-dark
            echo "gruvbox-dark"
        case gruvbox-light
            echo "gruvbox-light"
        case nord
            echo "nord"
        case dracula
            echo "dracula"
        case solarized-dark
            echo "solarized-dark"
        case solarized-light
            echo "solarized-light"
    end
end

function __devbase_theme_get_vscode_theme
    set -l theme_name $argv[1]
    switch $theme_name
        case everforest-dark
            echo "Everforest Dark"
        case everforest-light
            echo "Everforest Light"
        case catppuccin-mocha
            echo "Catppuccin Mocha"
        case catppuccin-latte
            echo "Catppuccin Latte"
        case tokyonight-night
            echo "Tokyo Night"
        case tokyonight-day
            echo "Tokyo Night Light"
        case gruvbox-dark
            echo "Gruvbox Dark Medium"
        case gruvbox-light
            echo "Gruvbox Light Medium"
        case nord
            echo "Nord"
        case dracula
            echo "Dracula Theme"
        case solarized-dark
            echo "Solarized Dark+"
        case solarized-light
            echo "Solarized Light+"
    end
end

function __devbase_theme_update_nvim --description "Update Neovim colorscheme"
    set -l theme_name $argv[1]
    
    if not test -d ~/.config/nvim
        return 0
    end
    
    switch $theme_name
        case everforest-dark
            printf 'return { { "sainnhe/everforest", lazy = false, priority = 1000, config = function() vim.g.everforest_background = "hard" vim.cmd("colorscheme everforest") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
        case everforest-light
            printf 'return { { "sainnhe/everforest", lazy = false, priority = 1000, config = function() vim.g.everforest_background = "soft" vim.o.background = "light" vim.cmd("colorscheme everforest") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
        case catppuccin-mocha
            printf 'return { { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000, config = function() require("catppuccin").setup({ flavour = "mocha" }) vim.cmd("colorscheme catppuccin") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
        case catppuccin-latte
            printf 'return { { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000, config = function() require("catppuccin").setup({ flavour = "latte" }) vim.o.background = "light" vim.cmd("colorscheme catppuccin") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
        case tokyonight-night
            printf 'return { { "folke/tokyonight.nvim", lazy = false, priority = 1000, config = function() require("tokyonight").setup({ style = "night" }) vim.cmd("colorscheme tokyonight") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
        case tokyonight-day
            printf 'return { { "folke/tokyonight.nvim", lazy = false, priority = 1000, config = function() require("tokyonight").setup({ style = "day" }) vim.o.background = "light" vim.cmd("colorscheme tokyonight") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
        case gruvbox-dark
            printf 'return { { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000, config = function() vim.o.background = "dark" vim.cmd("colorscheme gruvbox") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
        case gruvbox-light
            printf 'return { { "sainnhe/gruvbox-material", lazy = false, priority = 1000, config = function() vim.g.gruvbox_material_background = "medium" vim.cmd("set background=light") vim.cmd("colorscheme gruvbox-material") end } }' >~/.config/nvim/lua/plugins/colorscheme.lua
        case nord
            printf 'return { { "shaunsingh/nord.nvim", lazy = false, priority = 1000, config = function() vim.cmd("colorscheme nord") end } }' >~/.config/nvim/lua/plugins/colorscheme.lua
        case dracula
            printf 'return { { "Mofiqul/dracula.nvim", lazy = false, priority = 1000, config = function() vim.cmd("colorscheme dracula") end } }' >~/.config/nvim/lua/plugins/colorscheme.lua
        case solarized-dark
            printf 'return { { "maxmx03/solarized.nvim", lazy = false, priority = 1000, config = function() vim.o.background = "dark" vim.cmd("colorscheme solarized") end } }' >~/.config/nvim/lua/plugins/colorscheme.lua
        case solarized-light
            printf 'return { { "maxmx03/solarized.nvim", lazy = false, priority = 1000, config = function() vim.o.background = "light" vim.cmd("colorscheme solarized") end } }' >~/.config/nvim/lua/plugins/colorscheme.lua
    end
end

function __devbase_theme_update_vifm --description "Update vifm colorscheme"
    set -l theme_name $argv[1]
    
    if not test -f ~/.config/vifm/vifmrc
        return 0
    end
    
    switch $theme_name
        case solarized-dark
            sed -i 's/^colorscheme .*/colorscheme solarized-dark/' ~/.config/vifm/vifmrc
        case solarized-light
            sed -i 's/^colorscheme .*/colorscheme solarized-light/' ~/.config/vifm/vifmrc
        case gruvbox-dark
            sed -i 's/^colorscheme .*/colorscheme gruvbox/' ~/.config/vifm/vifmrc
        case everforest-dark catppuccin-mocha tokyonight-night nord dracula
            sed -i 's/^colorscheme .*/colorscheme gruvbox/' ~/.config/vifm/vifmrc
        case everforest-light catppuccin-latte tokyonight-day gruvbox-light
            sed -i 's/^colorscheme .*/colorscheme solarized-light/' ~/.config/vifm/vifmrc
    end
end

function __devbase_theme_get_vscode_settings_path --description "Get VSCode settings file path"
    if test -d ~/.vscode-server/data/Machine
        echo ~/.vscode-server/data/Machine/settings.json
        return 0
    else if test -d ~/.config/Code/User
        echo ~/.config/Code/User/settings.json
        return 0
    end
    return 1
end

function __devbase_theme_update_vscode --description "Update VSCode theme"
    set -l theme_name $argv[1]
    set -l vscode_theme (__devbase_theme_get_vscode_theme $theme_name)
    set -l settings_file (__devbase_theme_get_vscode_settings_path)
    
    if test -z "$settings_file"
        return 1
    end
    
    if test -f $settings_file
        if command -v jq &>/dev/null
            jq --arg theme "$vscode_theme" '. + {"workbench.colorTheme": $theme}' $settings_file > $settings_file.tmp
            and mv $settings_file.tmp $settings_file
        end
    else
        mkdir -p (dirname $settings_file)
        printf '{\n  "workbench.colorTheme": "%s"\n}\n' "$vscode_theme" > $settings_file
    end
end

function __devbase_theme_get_fzf_opts
    set -l theme_name $argv[1]
    switch $theme_name
        case everforest-dark
            echo "--color=dark --color=fg:#d3c6aa,bg:#2d353b,hl:#a7c080 --color=fg+:#d3c6aa,bg+:#3d484d,hl+:#a7c080 --color=info:#e67e80,prompt:#a7c080,pointer:#e67e80 --color=marker:#a7c080,spinner:#e67e80,header:#a7c080"
        case everforest-light
            echo "--color=light --color=fg:#5c6a72,bg:#fdf6e3,hl:#35a77c --color=fg+:#5c6a72,bg+:#f4f0d0,hl+:#35a77c --color=info:#5c6a72,prompt:#5c6a72,pointer:#d73a49 --color=marker:#5c6a72,spinner:#5c6a72,header:#5c6a72"
        case catppuccin-mocha
            echo "--color=dark --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
        case catppuccin-latte
            echo "--color=light --color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 --color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 --color=marker:#dc8a78,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39"
        case tokyonight-night
            echo "--color=dark --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7 --color=fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff --color=marker:#7dcfff,spinner:#7dcfff,header:#7dcfff"
        case tokyonight-day
            echo "--color=light --color=fg:#3760bf,bg:#e1e2e7,hl:#2e7de9 --color=fg+:#3760bf,bg+:#c4c8da,hl+:#2e7de9 --color=info:#188092,prompt:#188092,pointer:#188092 --color=marker:#188092,spinner:#188092,header:#188092"
        case gruvbox-dark
            echo "--color=dark --color=fg:#ebdbb2,bg:#282828,hl:#fe8019 --color=fg+:#ebdbb2,bg+:#3c3836,hl+:#fe8019 --color=info:#83a598,prompt:#b8bb26,pointer:#fb4934 --color=marker:#fb4934,spinner:#fb4934,header:#fb4934"
        case gruvbox-light
            echo "--color=light --color=fg:#3c3836,bg:#fbf1c7,hl:#af3a03 --color=fg+:#3c3836,bg+:#ebdbb2,hl+:#af3a03 --color=info:#076678,prompt:#79740e,spinner:#8f3f71,pointer:#076678,marker:#8f5902,header:#9d0006"
        case nord
            echo "--color=dark --color=fg:#d8dee9,bg:#2e3440,hl:#88c0d0 --color=fg+:#eceff4,bg+:#3b4252,hl+:#8fbcbb --color=info:#81a1c1,prompt:#88c0d0,pointer:#88c0d0 --color=marker:#a3be8c,spinner:#ebcb8b,header:#5e81ac"
        case dracula
            echo "--color=dark --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#ff79c6 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
        case solarized-dark
            echo "--color=dark --color=fg:#839496,bg:#002b36,hl:#b58900 --color=fg+:#839496,bg+:#073642,hl+:#859900 --color=info:#268bd2,prompt:#859900,pointer:#dc322f --color=marker:#dc322f,spinner:#b58900,header:#586e75"
        case solarized-light
            echo "--color=light --color=fg:#657b83,bg:#fdf6e3,hl:#b58900 --color=fg+:#657b83,bg+:#eee8d5,hl+:#859900 --color=info:#268bd2,prompt:#859900,pointer:#dc322f --color=marker:#dc322f,spinner:#b58900,header:#93a1a1"
    end
end

function __devbase_theme_set_environment_vars --description "Set BAT_THEME and FZF environment variables"
    set -l theme_name $argv[1]
    set -l bat_theme (__devbase_theme_get_bat_theme $theme_name)
    set -l fzf_opts (__devbase_theme_get_fzf_opts $theme_name)
    
    set -gx BAT_THEME $bat_theme
    set -gx FZF_DEFAULT_OPTS $fzf_opts
end

function __devbase_theme_configure_git --description "Configure git delta settings"
    set -l theme_name $argv[1]
    set -l bat_theme (__devbase_theme_get_bat_theme $theme_name)
    
    git config --global delta.syntax-theme $bat_theme
    if __devbase_theme_is_light $theme_name
        git config --global delta.dark "false"
    else
        git config --global delta.dark "true"
    end
end

function __devbase_theme_update_btop --description "Update btop configuration"
    set -l theme_name $argv[1]
    set -l btop_theme (__devbase_theme_get_btop_theme $theme_name)
    
    if test -f ~/.config/btop/btop.conf
        sed -i "s/^color_theme = .*/color_theme = \"$btop_theme\"/" ~/.config/btop/btop.conf
    end
end

function __devbase_theme_update_eza --description "Update eza theme symlink"
    set -l theme_name $argv[1]
    set -l eza_theme (__devbase_theme_get_eza_theme $theme_name)
    
    if test -d ~/.config/eza
        ln -sf "$eza_theme" ~/.config/eza/theme.yml
    end
end

function __devbase_theme_update_k9s --description "Update K9s skin configuration"
    set -l theme_name $argv[1]
    set -l k9s_skin (__devbase_theme_get_k9s_skin $theme_name)
    
    if test -f ~/.config/k9s/config.yaml
        sed -i "s/^  skin: .*/  skin: $k9s_skin/" ~/.config/k9s/config.yaml
    end
end

function __devbase_theme_update_lazygit --description "Update Lazygit theme configuration"
    set -l theme_name $argv[1]
    
    if test -f ~/.config/lazygit/config.yml
        if __devbase_theme_is_light $theme_name
            sed -i 's/lightTheme: .*/lightTheme: true/' ~/.config/lazygit/config.yml
        else
            sed -i 's/lightTheme: .*/lightTheme: false/' ~/.config/lazygit/config.yml
        end
    end
end

function __devbase_theme_update_zellij --description "Update Zellij theme configuration"
    set -l theme_name $argv[1]
    set -l zellij_theme (__devbase_theme_get_zellij_theme $theme_name)
    
    if test -f ~/.config/zellij/config.kdl
        sed -i "s/^theme .*/theme \"$zellij_theme\"/" ~/.config/zellij/config.kdl
    end
end

function __devbase_theme_update_cli_tools --description "Update all CLI tool configurations"
    set -l theme_name $argv[1]
    
    __devbase_theme_update_nvim $theme_name
    __devbase_theme_update_vifm $theme_name
    __devbase_theme_update_btop $theme_name
    __devbase_theme_update_eza $theme_name
    __devbase_theme_update_k9s $theme_name
    __devbase_theme_update_lazygit $theme_name
    __devbase_theme_update_zellij $theme_name
end

function __devbase_theme_update_terminals --description "Update all terminal emulator themes"
    set -l theme_name $argv[1]
    set -l results ""
    
    # Windows Terminal
    if functions -q update-windows-terminal-theme
        if update-windows-terminal-theme
            set results "$results wt:true"
        else
            set results "$results wt:false"
        end
    else
        set results "$results wt:false"
    end
    
    # Ghostty
    if functions -q update-ghostty-theme
        if update-ghostty-theme
            set results "$results ghostty:true"
        else
            set results "$results ghostty:false"
        end
    else
        set results "$results ghostty:false"
    end
    
    # GNOME Terminal
    if functions -q update-gnome-terminal-theme
        if update-gnome-terminal-theme
            set results "$results gnome:true"
        else
            set results "$results gnome:false"
        end
    else
        set results "$results gnome:false"
    end
    
    # VSCode
    if __devbase_theme_update_vscode $theme_name
        set results "$results vscode:true"
    else
        set results "$results vscode:false"
    end
    
    echo $results
end

function __devbase_theme_save_preference --description "Save theme preference and update LS_COLORS"
    set -l theme_name $argv[1]
    
    set -e DEVBASE_THEME
    set -U DEVBASE_THEME $theme_name
    
    if functions -q update_ls_colors
        update_ls_colors
    end
end

function __devbase_theme_parse_terminal_results --description "Parse terminal update results"
    set -l results $argv[1]
    set -l wt_updated false
    set -l ghostty_updated false
    set -l gnome_updated false
    set -l vscode_updated false
    
    for result in (string split " " $results)
        switch $result
            case "wt:true"
                set wt_updated true
            case "ghostty:true"
                set ghostty_updated true
            case "gnome:true"
                set gnome_updated true
            case "vscode:true"
                set vscode_updated true
        end
    end
    
    echo "$wt_updated $ghostty_updated $gnome_updated $vscode_updated"
end

function devbase-theme --description "Set theme for multiple CLI tools"
    set -l theme_name $argv[1]
    
    # Validate input
    if test -z "$theme_name"
        __devbase_theme_show_usage
        return 1
    end
    
    if not __devbase_theme_validate $theme_name
        return 1
    end
    
    # Set environment variables
    __devbase_theme_set_environment_vars $theme_name
    
    # Configure git delta
    __devbase_theme_configure_git $theme_name
    
    # Update CLI tools
    __devbase_theme_update_cli_tools $theme_name
    
    # Save preference (must be done before updating terminals since they read $DEVBASE_THEME)
    __devbase_theme_save_preference $theme_name
    
    # Update terminals and collect results
    set -l terminal_results (__devbase_theme_update_terminals $theme_name)
    
    # Parse results and print
    set -l parsed (string split " " (__devbase_theme_parse_terminal_results $terminal_results))
    __devbase_theme_print_results $theme_name $parsed[1] $parsed[2] $parsed[3] $parsed[4]
end

function __devbase_theme_print_results --description "Print theme update results"
    set -l theme_name $argv[1]
    set -l wt_updated $argv[2]
    set -l ghostty_updated $argv[3]
    set -l gnome_terminal_updated $argv[4]
    set -l vscode_updated $argv[5]
    
    printf "✓ Theme set to: %s\n" $theme_name
    printf "  Applies instantly: bat, delta, btop, eza, FZF\n"
    
    if test $wt_updated = true
        printf "  Windows Terminal: Theme updated\n"
    else if uname -r | grep -qi microsoft
        printf "  Windows Terminal: Update failed (see errors above)\n"
    end
    
    if test $ghostty_updated = true
        printf "  Ghostty: Config updated (reload with Ctrl+Shift+Comma or restart)\n"
    end
    
    if test $gnome_terminal_updated = true
        printf "  GNOME Terminal: Theme updated (applies immediately)\n"
    end
    
    if test $vscode_updated = true
        printf "  VSCode: Theme updated (reload window to apply)\n"
    end
    
    printf "  Restart if running: Neovim, vifm, Lazygit, Zellij, K9s\n"
end
