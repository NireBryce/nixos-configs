{ 
    nixos = 
    { pkgs, ... }:
    {
        environment.shells = with pkgs; [
            fish
        ];
    }; 
    homeManager = 
    { pkgs,... }:
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
        environment.pathsToLink = [
            "/share/fish"
        ];
        environment.systemPackages = with pkgs; [
            fishPlugins.fzf-fish
        ];
    };
}
