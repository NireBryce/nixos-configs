# desc = "";
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

