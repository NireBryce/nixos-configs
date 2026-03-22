{ self, inputs, ...}:
{ flake.homeModules.elly-shell-fish = 
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
