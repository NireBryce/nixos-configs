# desc = "";
{ den.aspects.pkgs-cli.homeManager = 
{ ... }:

{
    programs.broot = {
        enable  = true;
        enableZshIntegration    = true;
        enableBashIntegration   = true;
        enableFishIntegration   = true;
    };

}
;}
