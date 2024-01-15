# ~/.config/fish/conf.d/terminal-title.fish
# Dynamic terminal title using Fish's built-in function

if status is-interactive
    function fish_title
        # Shows: "command ~/path" when running, just "~/path" when idle
        if test -n "$argv"
            printf "%s %s" (string split ' ' -- $argv)[1] (prompt_pwd)
        else
            prompt_pwd
        end
    end
end