# desc = "";
{ flake.modules.homeManager.packages.shellUtil.broot =
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
