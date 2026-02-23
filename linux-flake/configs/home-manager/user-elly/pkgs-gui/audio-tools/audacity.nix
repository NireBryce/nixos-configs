# desc = "Audacity audio editor";
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
{
home.packages = with pkgs; [
        audacity
    ];
# TODO: make this only load for workstation or audio workstation
}
;}
