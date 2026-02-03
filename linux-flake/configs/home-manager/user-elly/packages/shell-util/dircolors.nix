# desc = "";
{ flake.modules.homeManager.packages.shellUtil.dircolors =
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
