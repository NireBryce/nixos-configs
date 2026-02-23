# desc = "";
{ den.aspects.pkgs-cli.homeManager = 
{ ... }:
{
    programs.tmux = {
        enable = true;
    };
}
;}
