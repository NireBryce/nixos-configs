{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.broot ];

    flake.modules.homeManager.broot =
# desc = "";

{
    programs.broot = {
        enable  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
    };

}
;}
