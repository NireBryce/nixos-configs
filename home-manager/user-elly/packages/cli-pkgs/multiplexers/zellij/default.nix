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
            source = ./config.kdl;
        };
    };

    programs.zellij = {
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
    };
}
