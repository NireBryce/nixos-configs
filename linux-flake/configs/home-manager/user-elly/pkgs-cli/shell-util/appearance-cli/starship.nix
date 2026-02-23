# desc = "";
{ den.aspects.pkgs-cli.homeManager = 
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
