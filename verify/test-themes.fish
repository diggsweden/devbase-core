#!/usr/bin/env fish
# Test all themes with all programs - improved version

# === Configuration ===
set -g ALL_THEMES everforest-dark everforest-light catppuccin-mocha catppuccin-latte \
                  tokyonight-night tokyonight-day gruvbox-dark gruvbox-light \
                  nord dracula solarized-dark solarized-light

set -g LIGHT_THEMES solarized-light everforest-light catppuccin-latte tokyonight-day gruvbox-light

# === Helper Functions ===
function handle_sigint --on-signal INT
    echo -e "\n\nInterrupted! Cleaning up..."
    rm -f /tmp/test-theme.py
    echo "Restoring default theme..."
    devbase-theme everforest-dark >/dev/null 2>&1
    exit 130
end

function wait_enter
    if test -n "$argv[1]"
        echo "$argv[1]"
    end
    read -P "" input
    # Check if user wants to quit
    if test "$input" = "q" -o "$input" = "Q"
        handle_sigint
    end
end



function show_header
    clear
    echo "=========================================="
    echo "THEME: $DEVBASE_THEME"
    echo "=========================================="
    echo "=== $argv[1]. $argv[2] ==="
    echo $argv[3]
end

function test_app
    set -l cmd $argv[1]
    set -l num $argv[2]
    set -l name $argv[3] 
    set -l desc $argv[4]
    set -l run $argv[5]
    set -l exit_hint $argv[6]
    
    type -q $cmd || return
    show_header $num "$name" "$desc - $exit_hint"
    eval $run
    wait_enter "Press ENTER to continue..."
end

# === Theme Mappings ===
function get_mapped_value
    set -l theme $argv[1]
    set -l type $argv[2]
    
    switch $type
        case "k9s"
            # Use the actual devbase-theme function's mapping
            __devbase_theme_get_k9s_skin $theme
        
        case "vscode"
            # VS Code theme names
            switch $theme
                case "everforest-dark"; echo "Everforest Dark"
                case "everforest-light"; echo "Everforest Light"
                case "catppuccin-mocha"; echo "Catppuccin Mocha"
                case "catppuccin-latte"; echo "Catppuccin Latte"
                case "tokyonight-night"; echo "Tokyo Night"
                case "tokyonight-day"; echo "Tokyo Night Light"
                case "gruvbox-dark"; echo "Gruvbox Dark Medium"
                case "gruvbox-light"; echo "Gruvbox Light Medium"
                case "nord"; echo "Nord"
                case "dracula"; echo "Dracula"
                case "solarized-dark"; echo "Solarized Dark"
                case "solarized-light"; echo "Solarized Light"
            end
    end
end

# === Test Functions ===
function run_core_tests
    set -l file $argv[1]
    
    # bat
    show_header 1 "BAT" "Syntax highlighting test"
    bat --style=full --paging=never $file
    wait_enter "Press ENTER to continue..."
    
    # delta
    show_header 2 "DELTA" "Git diff colors"
    printf "diff --git a/test b/test\n@@ -1,2 +1,2 @@\n-old line\n+new line\n" | delta
    wait_enter "Press ENTER to continue..."
    
    # eza
    show_header 3 "EZA" "Colored directory listing"
    eza -la --icons --color=always ~/
    wait_enter "Press ENTER to continue..."
    
    # fzf
    show_header 4 "FZF" "Fuzzy finder - Press ESC to exit, then ENTER to continue"
    ls ~ | fzf --height=50% --preview 'echo {}'
    wait_enter "Press ENTER to continue..."
    
    # btop
    show_header 5 "BTOP" "System monitor - Press 'q' to exit, then ENTER to continue"
    btop
    wait_enter "Press ENTER to continue..."
end

function test_config_app
    set -l theme $argv[1]
    set -l app $argv[2]
    set -l file $argv[3]
    
    switch $app
        case k9s
            type -q k9s || return
            show_header 9 "K9S" "Kubernetes UI - Press :q to exit"
            if test -f ~/.config/k9s/config.yaml
                echo "Expected skin: "(get_mapped_value $theme k9s)
                echo "Current: "(grep "skin:" ~/.config/k9s/config.yaml | awk '{print $2}')
                echo ""
                echo "Note: Will show connection error if no cluster"
                k9s 2>/dev/null || echo "No cluster available (theme still applied)"
                wait_enter "Press ENTER to continue..."
            end
            
        case vscode
            type -q code || return
            show_header 10 "VS CODE" "Editor theme - Close window when done"
            echo "Expected: "(get_mapped_value $theme vscode)
            if test -f ~/.config/Code/User/settings.json
                echo "Current: "(grep '"workbench.colorTheme"' ~/.config/Code/User/settings.json | cut -d':' -f2 | tr -d '," ')
            end
            echo ""
            echo "Note: May need Ctrl+Shift+P > Reload Window"
            code --new-window $file >/dev/null 2>&1 &
            sleep 1
            echo "VS Code launched in background"
            wait_enter "Press ENTER to continue..."
            

    end
end

# === Main ===
function main
    # Parse arguments
    set -l themes $ALL_THEMES
    if test (count $argv) -gt 0
        if contains -- $argv[1] --help -h
            echo "Usage: $0 [theme-name|--quick]"
            echo "  --quick  Test current theme only"
            echo "Themes: $ALL_THEMES"
            return 0
        else if test "$argv[1]" = "--quick"
            set themes $DEVBASE_THEME
        else
            set themes $argv[1]
        end
    end
    
    # Signal handler handle_sigint is already defined with --on-signal INT
    
    # Create test file once at start
    set -l test_file /tmp/test-theme.py
    echo 'def example():
    """Docstring"""
    items = [1, 2, 3]
    # TODO: test
    return True' > $test_file
    
    echo "TIP: Press 'q' + ENTER at any prompt to quit, or use Ctrl+C"
    echo ""
    
    # Test each theme
    for theme in $themes
        # Check if we should stop
        if not test -f /tmp/test-theme.py
            echo "Test interrupted"
            return 1
        end
        
        clear
        echo "==================== TESTING: $theme ===================="
        devbase-theme $theme && sleep 0.5
        
        echo "Theme: $DEVBASE_THEME | BAT: $BAT_THEME"
        
        # Show color preview
        echo ""
        echo (set_color red)"● RED"(set_color normal)"    "(set_color green)"● GREEN"(set_color normal)"    "(set_color blue)"● BLUE"(set_color normal)
        echo (set_color yellow)"● YELLOW"(set_color normal)" "(set_color magenta)"● MAGENTA"(set_color normal)"  "(set_color cyan)"● CYAN"(set_color normal)
        
        if contains $theme $LIGHT_THEMES
            echo (set_color black; set_color --background white)" LIGHT THEME "(set_color normal)
        else
            echo (set_color white; set_color --background black)" DARK THEME "(set_color normal)
        end
        
        echo ""
        wait_enter "Press ENTER to start testing..."
        
        # Core tests
        run_core_tests $test_file
        
        # Optional CLI tools
        test_app nvim 6 "NEOVIM" "Editor" "nvim $test_file" "Press :q to exit"
        test_app vifm 7 "VIFM" "File manager" "vifm" "Press :q to exit"
        test_app lazygit 8 "LAZYGIT" "Git UI" "cd ~/devbase-core 2>/dev/null && lazygit" "Press q to exit"
        test_app zellij 12 "ZELLIJ" "Multiplexer" "zellij" "Type 'exit' to quit"
        
        # Config-based apps
        test_config_app $theme k9s
        test_config_app $theme vscode $test_file
        
        # Summary
        clear
        echo "=== $theme Complete ==="
        echo "Tested: bat, delta, eza, fzf, btop"
        type -q nvim && echo "        nvim"
        type -q vifm && echo "        vifm"
        type -q lazygit && echo "        lazygit"
        type -q k9s && echo "        k9s"
        type -q code && echo "        VS Code"
        type -q zellij && echo "        zellij"
        echo ""
        wait_enter "Next theme..."
    end
    
    rm -f $test_file
    echo "Testing complete!"
end

main $argv