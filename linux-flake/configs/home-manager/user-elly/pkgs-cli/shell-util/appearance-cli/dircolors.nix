# desc = "";
{ den.aspects.hm.provides.pkgs-cli = 
{ ... }:

{
    programs.dircolors = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
    };
}
;}
