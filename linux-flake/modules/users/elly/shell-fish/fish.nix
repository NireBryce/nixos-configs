{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.elly-shell-fish ];

    flake.modules.homeManager.elly-shell-fish = 
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
