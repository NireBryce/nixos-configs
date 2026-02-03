# desc = "";
{ flake.modules.homeManager.packages.shellUtil.direnv =
{ ... }:

{
    programs.direnv = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableNushellIntegration = true;
        nix-direnv.enable = true;
    };
}
;}
