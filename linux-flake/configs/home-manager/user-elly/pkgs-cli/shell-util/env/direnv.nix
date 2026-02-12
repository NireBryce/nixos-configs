# desc = "";
{ den.aspects.hm.provides.pkgs-cli = 
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
