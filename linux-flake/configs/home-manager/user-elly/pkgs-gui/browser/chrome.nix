# desc = "  ";
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
{
    # todo: this is also installed as a system package, does that matter?
    home.packages = with pkgs; [ google-chrome ];
}
;}
