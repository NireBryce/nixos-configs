{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.zoxide ];

    flake.modules.homeManager.zoxide =
# desc = "";

{
    programs.zoxide = {      
        enable                  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        # options                 = [ "--cmd x" ];  # TODO: remove when you remove zi or zsh
    };    
}
;}
