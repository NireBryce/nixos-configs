{
    description = "zellij terminal multiplexer";
    
    homeManager =
    { pkgs, ... }:
    {
    home.packages = with pkgs; [
        zellij
    ];

    home.file = {
        "./.config/zellij/config.kdl" = {
            source = ./config/config.kdl;
        };
    };

    programs.zellij = {
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
    };
    };
}
