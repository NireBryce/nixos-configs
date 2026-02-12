# desc = "";
{ den.aspects.hm.provides.pkgs-cli = 
{ ... }:

{
    programs.starship = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableFishIntegration = true;
    };
}

;}
