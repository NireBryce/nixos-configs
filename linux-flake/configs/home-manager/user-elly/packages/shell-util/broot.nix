# desc = "";
{ den.bundles.hm.shell-util =
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
