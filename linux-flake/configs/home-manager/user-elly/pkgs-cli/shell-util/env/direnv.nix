# desc = "";
{ den.aspects.pkgs-cli.homeManager = 
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
