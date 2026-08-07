{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.eza ];

    flake.modules.homeManager.eza =
# desc = "";

{
    programs.eza = {
        enable  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
        icons = "auto";
        colors = "auto";
        git = true;
        extraOptions = [ 
            "-1"                        # portrait mode
            "--header" 
            "--hyperlink" 
            "--group-directories-first" 
        ];
    
    };
}
;}
