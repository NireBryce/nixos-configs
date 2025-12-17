{ pkgs, ... }:
{
    programs.fish = {
        enable = true;
        enableCompletion = true;
        promptInit = ''
            function fish_prompt
                starship prompt
            end
        '';
        generateCompletions = true;
    };
}
