# desc = "";
{ den.aspects.pkgs-cli.homeManager = 
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
