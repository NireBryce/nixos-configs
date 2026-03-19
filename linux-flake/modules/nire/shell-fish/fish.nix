{ nire.shell-fish.homeManager = 
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
