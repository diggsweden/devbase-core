function set-fzf-theme --description "Set FZF colors based on DEVBASE_THEME"
    # Apply FZF color scheme based on current theme
    # Called on shell startup and when theme changes
    
    if not set -q DEVBASE_THEME
        return 0
    end
    
    switch $DEVBASE_THEME
        case "everforest-dark"
            set -gx FZF_DEFAULT_OPTS "--color=dark --color=fg:#d3c6aa,bg:#2d353b,hl:#a7c080 --color=fg+:#d3c6aa,bg+:#3d484d,hl+:#a7c080 --color=info:#e67e80,prompt:#a7c080,pointer:#e67e80 --color=marker:#a7c080,spinner:#e67e80,header:#a7c080"
            
        case "everforest-light"
            set -gx FZF_DEFAULT_OPTS "--color=light --color=fg:#5c6a72,bg:#fdf6e3,hl:#35a77c --color=fg+:#5c6a72,bg+:#f4f0d0,hl+:#35a77c --color=info:#5c6a72,prompt:#5c6a72,pointer:#d73a49 --color=marker:#5c6a72,spinner:#5c6a72,header:#5c6a72"
            
        case "catppuccin-mocha"
            set -gx FZF_DEFAULT_OPTS "--color=dark --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
            
        case "catppuccin-latte"
            set -gx FZF_DEFAULT_OPTS "--color=light --color=bg+:#ccd0da,bg:#eff1f5,spinner:#dc8a78,hl:#d20f39 --color=fg:#4c4f69,header:#d20f39,info:#8839ef,pointer:#dc8a78 --color=marker:#dc8a78,fg+:#4c4f69,prompt:#8839ef,hl+:#d20f39"
            
        case "tokyonight-night"
            set -gx FZF_DEFAULT_OPTS "--color=dark --color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7 --color=fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff --color=info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff --color=marker:#7dcfff,spinner:#7dcfff,header:#7dcfff"
            
        case "tokyonight-day"
            set -gx FZF_DEFAULT_OPTS "--color=light --color=fg:#3760bf,bg:#e1e2e7,hl:#2e7de9 --color=fg+:#3760bf,bg+:#c4c8da,hl+:#2e7de9 --color=info:#188092,prompt:#188092,pointer:#188092 --color=marker:#188092,spinner:#188092,header:#188092"
            
        case "gruvbox-dark"
            set -gx FZF_DEFAULT_OPTS "--color=dark --color=fg:#ebdbb2,bg:#282828,hl:#fe8019 --color=fg+:#ebdbb2,bg+:#3c3836,hl+:#fe8019 --color=info:#83a598,prompt:#b8bb26,pointer:#fb4934 --color=marker:#fb4934,spinner:#fb4934,header:#fb4934"
            
        case "gruvbox-light"
            set -gx FZF_DEFAULT_OPTS "--color=light --color=fg:#3c3836,bg:#fbf1c7,hl:#af3a03 --color=fg+:#3c3836,bg+:#ebdbb2,hl+:#af3a03 --color=info:#076678,prompt:#79740e,pointer:#9d0006 --color=marker:#9d0006,spinner:#9d0006,header:#9d0006"
    end
    
    return 0
end
