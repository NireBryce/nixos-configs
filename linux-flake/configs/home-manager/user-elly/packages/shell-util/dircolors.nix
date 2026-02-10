# desc = "";
{ den.bundles.hm.shell-util =
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
