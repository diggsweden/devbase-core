function devbase-theme --description "Set theme for multiple CLI tools"
    set -l theme_name $argv[1]
    
    if test -z "$theme_name"
        printf "Usage: devbase-theme <name>\n"
        printf "\nAvailable themes:\n"
        printf "  Everforest:  everforest-dark (default), everforest-light\n"
        printf "  Catppuccin:  catppuccin-mocha, catppuccin-latte\n"
        printf "  Tokyo Night: tokyonight-night, tokyonight-day\n"
        printf "  Gruvbox:     gruvbox-dark, gruvbox-light\n"
        return 1
    end
    
    # Validate theme name
    set -l valid_themes everforest-dark everforest-light \
                        catppuccin-mocha catppuccin-latte \
                        tokyonight-night tokyonight-day \
                        gruvbox-dark gruvbox-light
    
    if not contains $theme_name $valid_themes
        printf "Unknown theme: %s\n" $theme_name
        printf "\nAvailable themes:\n"
        printf "  Everforest:  everforest-dark (default), everforest-light\n"
        printf "  Catppuccin:  catppuccin-mocha, catppuccin-latte\n"
        printf "  Tokyo Night: tokyonight-night, tokyonight-day\n"
        printf "  Gruvbox:     gruvbox-dark, gruvbox-light\n"
        return 1
    end
    
    # Determine if light or dark theme
    set -l is_light false
    if string match -q "*-light" $theme_name; or string match -q "*-latte" $theme_name; or string match -q "*-day" $theme_name
        set is_light true
    end
    
    # Declare theme variables before switch
    set btop_theme ""
    
    # Apply theme settings based on theme family
    switch $theme_name
        # Everforest themes
        case everforest-dark
            set -gx BAT_THEME "Monokai Extended"
            set btop_theme "everforest-dark-hard"
            set -gx FZF_DEFAULT_OPTS "--color=dark --color=fg:#d3c6aa,bg:#2d353b,hl:#a7c080 --color=fg+:#d3c6aa,bg+:#3d484d,hl+:#a7c080 --color=info:#e67e80,prompt:#a7c080,pointer:#e67e80 --color=marker:#a7c080,spinner:#e67e80,header:#a7c080"
            git config --global delta.syntax-theme "Monokai Extended"
            git config --global delta.dark "true"
            if test -d ~/.config/nvim
                printf 'return { { "sainnhe/everforest", lazy = false, priority = 1000, config = function() vim.g.everforest_background = "hard" vim.cmd("colorscheme everforest") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
            end
            if test -f ~/.config/vifm/vifmrc
                sed -i 's/^colorscheme .*/colorscheme gruvbox/' ~/.config/vifm/vifmrc
            end
            
        case everforest-light
            set -gx BAT_THEME "GitHub"
            set btop_theme "everforest-light-medium"
            set -gx FZF_DEFAULT_OPTS "--color=light --color=fg:#5c6a72,bg:#fdf6e3,hl:#35a77c --color=fg+:#5c6a72,bg+:#f4f0d0,hl+:#35a77c --color=info:#5c6a72,prompt:#5c6a72,pointer:#d73a49 --color=marker:#5c6a72,spinner:#5c6a72,header:#5c6a72"
            git config --global delta.syntax-theme "GitHub"
            git config --global delta.dark "false"
            if test -d ~/.config/nvim
                printf 'return { { "sainnhe/everforest", lazy = false, priority = 1000, config = function() vim.g.everforest_background = "soft" vim.o.background = "light" vim.cmd("colorscheme everforest") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
            end
            if test -f ~/.config/vifm/vifmrc
                sed -i 's/^colorscheme .*/colorscheme solarized-light/' ~/.config/vifm/vifmrc
            end
            
        # Catppuccin themes
        case catppuccin-mocha
            set -gx BAT_THEME "Dracula"
            set btop_theme "catppuccin_mocha"
            set -gx FZF_DEFAULT_OPTS "--color=dark --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
            git config --global delta.syntax-theme "Dracula"
            git config --global delta.dark "true"
            if test -d ~/.config/nvim
                printf 'return { { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000, config = function() require("catppuccin").setup({ flavour = "mocha" }) vim.cmd("colorscheme catppuccin") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
            end
            if test -f ~/.config/vifm/vifmrc
                sed -i 's/^colorscheme .*/colorscheme solarized-dark/' ~/.config/vifm/vifmrc
            end
            

        case catppuccin-latte
            set -gx BAT_THEME "OneHalfLight"
            set btop_theme "catppuccin_latte"
            set -gx FZF_DEFAULT_OPTS "--color=light --color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 --color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 --color=marker:#dc8a78,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39"
            git config --global delta.syntax-theme "OneHalfLight"
            git config --global delta.dark "false"
            if test -d ~/.config/nvim
                printf 'return { { "catppuccin/nvim", name = "catppuccin", lazy = false, priority = 1000, config = function() require("catppuccin").setup({ flavour = "latte" }) vim.o.background = "light" vim.cmd("colorscheme catppuccin") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
            end
            if test -f ~/.config/vifm/vifmrc
                sed -i 's/^colorscheme .*/colorscheme solarized-light/' ~/.config/vifm/vifmrc
            end
            
        # Tokyo Night themes
        case tokyonight-night
            set -gx BAT_THEME "Visual Studio Dark+"
            set btop_theme "tokyo-night"
            set -gx FZF_DEFAULT_OPTS "--color=dark --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7 --color=fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff --color=marker:#7dcfff,spinner:#7dcfff,header:#7dcfff"
            git config --global delta.syntax-theme "Visual Studio Dark+"
            git config --global delta.dark "true"
            if test -d ~/.config/nvim
                printf 'return { { "folke/tokyonight.nvim", lazy = false, priority = 1000, config = function() require("tokyonight").setup({ style = "night" }) vim.cmd("colorscheme tokyonight") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
            end
            if test -f ~/.config/vifm/vifmrc
                sed -i 's/^colorscheme .*/colorscheme solarized-dark/' ~/.config/vifm/vifmrc
            end
            

        case tokyonight-day
            set -gx BAT_THEME "GitHub"
            set btop_theme "tokyo-storm"
            set -gx FZF_DEFAULT_OPTS "--color=light --color=fg:#3760bf,bg:#e1e2e7,hl:#2e7de9 --color=fg+:#3760bf,bg+:#c4c8da,hl+:#2e7de9 --color=info:#188092,prompt:#188092,pointer:#188092 --color=marker:#188092,spinner:#188092,header:#188092"
            git config --global delta.syntax-theme "GitHub"
            git config --global delta.dark "false"
            if test -d ~/.config/nvim
                printf 'return { { "folke/tokyonight.nvim", lazy = false, priority = 1000, config = function() require("tokyonight").setup({ style = "day" }) vim.o.background = "light" vim.cmd("colorscheme tokyonight") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
            end
            if test -f ~/.config/vifm/vifmrc
                sed -i 's/^colorscheme .*/colorscheme solarized-light/' ~/.config/vifm/vifmrc
            end
            
        # Gruvbox themes
        case gruvbox-dark
            set -gx BAT_THEME "gruvbox-dark"
            set btop_theme "gruvbox_dark"
            set -gx FZF_DEFAULT_OPTS "--color=dark --color=fg:#ebdbb2,bg:#282828,hl:#fe8019 --color=fg+:#ebdbb2,bg+:#3c3836,hl+:#fe8019 --color=info:#83a598,prompt:#b8bb26,pointer:#fb4934 --color=marker:#fb4934,spinner:#fb4934,header:#fb4934"
            git config --global delta.syntax-theme "gruvbox-dark"
            git config --global delta.dark "true"
            if test -d ~/.config/nvim
                printf 'return { { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000, config = function() vim.o.background = "dark" vim.cmd("colorscheme gruvbox") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
            end
            if test -f ~/.config/vifm/vifmrc
                sed -i 's/^colorscheme .*/colorscheme gruvbox/' ~/.config/vifm/vifmrc
            end
            
        case gruvbox-light
            set -gx BAT_THEME "gruvbox-light"
            set btop_theme "gruvbox_light"
            set -gx FZF_DEFAULT_OPTS "--color=light --color=fg:#3c3836,bg:#fbf1c7,hl:#af3a03 --color=fg+:#3c3836,bg+:#ebdbb2,hl+:#af3a03 --color=info:#076678,prompt:#79740e,pointer:#9d0006 --color=marker:#9d0006,spinner:#9d0006,header:#9d0006"
            git config --global delta.syntax-theme "gruvbox-light"
            git config --global delta.dark "false"
            if test -d ~/.config/nvim
                printf 'return { { "ellisonleao/gruvbox.nvim", lazy = false, priority = 1000, config = function() vim.o.background = "light" vim.cmd("colorscheme gruvbox") end } }' > ~/.config/nvim/lua/plugins/colorscheme.lua
            end
            if test -f ~/.config/vifm/vifmrc
                sed -i 's/^colorscheme .*/colorscheme solarized-light/' ~/.config/vifm/vifmrc
            end
    end
    
    # Update btop config
    if test -f ~/.config/btop/btop.conf
        sed -i "s/^color_theme = .*/color_theme = \"$btop_theme\"/" ~/.config/btop/btop.conf
    end
    
    # Update eza theme via symlink
    if test -d ~/.config/eza
        set -l eza_theme
        switch $theme_name
            case everforest-dark everforest-light
                set eza_theme "default.yml"
            case catppuccin-mocha catppuccin-latte
                set eza_theme "catppuccin.yml"
            case tokyonight-night tokyonight-day
                set eza_theme "tokyonight.yml"
            case gruvbox-dark
                set eza_theme "gruvbox-dark.yml"
            case gruvbox-light
                set eza_theme "gruvbox-light.yml"
        end
        ln -sf "$eza_theme" ~/.config/eza/theme.yml
    end
    
    # Update K9s skin config
    if test -f ~/.config/k9s/config.yaml
        set -l k9s_skin
        switch $theme_name
            case everforest-dark
                set k9s_skin "everforest-dark"
            case everforest-light
                set k9s_skin "everforest-light"
            case catppuccin-mocha
                set k9s_skin "catppuccin-mocha"
            case catppuccin-latte
                set k9s_skin "catppuccin-latte"
            case tokyonight-night
                set k9s_skin "gruvbox-dark"
            case tokyonight-day
                set k9s_skin "everforest-light"
            case gruvbox-dark
                set k9s_skin "gruvbox-dark"
            case gruvbox-light
                set k9s_skin "gruvbox-light"
        end
        sed -i "s/^  skin: .*/  skin: $k9s_skin/" ~/.config/k9s/config.yaml
    end
    
    # Update Lazygit config
    if test -f ~/.config/lazygit/config.yml
        if test $is_light = true
            sed -i 's/lightTheme: .*/lightTheme: true/' ~/.config/lazygit/config.yml
        else
            sed -i 's/lightTheme: .*/lightTheme: false/' ~/.config/lazygit/config.yml
        end
    end
    
    # Update Zellij config
    if test -f ~/.config/zellij/config.kdl
        set -l zellij_theme
        switch $theme_name
            case everforest-dark
                set zellij_theme "everforest-dark"
            case everforest-light
                set zellij_theme "everforest-light"
            case catppuccin-mocha
                set zellij_theme "catppuccin-mocha"
            case catppuccin-latte
                set zellij_theme "catppuccin-latte"
            case tokyonight-night
                set zellij_theme "tokyo-night"
            case tokyonight-day
                set zellij_theme "tokyo-night-light"
            case gruvbox-dark
                set zellij_theme "gruvbox-dark"
            case gruvbox-light
                set zellij_theme "gruvbox-light"
        end
        sed -i "s/^theme .*/theme \"$zellij_theme\"/" ~/.config/zellij/config.kdl
    end
    
    # Save theme preference
    set -e DEVBASE_THEME
    set -U DEVBASE_THEME $theme_name
    
    # Update LS_COLORS if the function exists
    if functions -q update_ls_colors
        update_ls_colors
    end
    
    # Update Windows Terminal theme if in WSL
    set -l wt_updated false
    if functions -q update-windows-terminal-theme
        if update-windows-terminal-theme
            set wt_updated true
        end
    end
    
    # Update Ghostty theme if on native Linux
    set -l ghostty_updated false
    if functions -q update-ghostty-theme
        if update-ghostty-theme
            set ghostty_updated true
        end
    end
    
    # Update GNOME Terminal theme if on native Linux
    set -l gnome_terminal_updated false
    if functions -q update-gnome-terminal-theme
        if update-gnome-terminal-theme
            set gnome_terminal_updated true
        end
    end
    
    # Update VSCode theme if VS Code is installed
    set -l vscode_updated false
    set -l settings_file ""
    
    # Check for VS Code settings location (WSL or native)
    if test -d ~/.vscode-server/data/Machine
        set settings_file ~/.vscode-server/data/Machine/settings.json
    else if test -d ~/.config/Code/User
        set settings_file ~/.config/Code/User/settings.json
    end
    
    if test -n "$settings_file"
        set -l vscode_theme
        switch $theme_name
            case everforest-dark
                set vscode_theme "Everforest Dark"
            case everforest-light
                set vscode_theme "Everforest Light"
            case catppuccin-mocha
                set vscode_theme "Catppuccin Mocha"
            case catppuccin-latte
                set vscode_theme "Catppuccin Latte"
            case tokyonight-night
                set vscode_theme "Tokyo Night"
            case tokyonight-day
                set vscode_theme "Tokyo Night Light"
            case gruvbox-dark
                set vscode_theme "Gruvbox Dark Medium"
            case gruvbox-light
                set vscode_theme "Gruvbox Light Medium"
        end
        
        if test -f $settings_file
            # Update existing settings file
            if command -v jq &>/dev/null
                # Use jq to update the theme setting
                jq --arg theme "$vscode_theme" '. + {"workbench.colorTheme": $theme}' $settings_file > $settings_file.tmp
                mv $settings_file.tmp $settings_file
            end
            set vscode_updated true
        else
            # Create new settings file with theme
            mkdir -p (dirname $settings_file)
            echo '{
  "workbench.colorTheme": "'$vscode_theme'"
}' > $settings_file
            set vscode_updated true
        end
    end
    
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
