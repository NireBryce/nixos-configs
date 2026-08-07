{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.dircolors ];

    flake.modules.homeManager.dircolors =
# desc = "";

{
    programs.dircolors = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
    };
}
;}
