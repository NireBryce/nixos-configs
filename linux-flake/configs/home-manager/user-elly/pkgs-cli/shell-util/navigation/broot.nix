# desc = "";
{ den.aspects.hm.provides.pkgs-cli = 
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
