# desc = "";
{ flake.modules.homeManager.packages.shellUtil.starship=
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
