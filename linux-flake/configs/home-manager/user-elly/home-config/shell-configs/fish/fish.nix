{flake.modules.homeManager.common.shells.fish = 
{ ... }:
{ 
    programs.fish = {
        enable = true;
        interactiveShellInit = ''
            function fish_prompt
                starship prompt
            end
        '';
        generateCompletions = true;
    };
};
}
