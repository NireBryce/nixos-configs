{
    pkgs, 
    ...
}:
 
{
    imports = [
    ];
    home.packages = with pkgs;[
        zellij
    ];
    home.file = {
        "./.config/zellij/config.kdl" = {
            source = ./zellij/config.kdl;
        };
    };

    programs.zellij = {
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
    };
}
