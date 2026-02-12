# desc = "Audacity audio editor";
{ den.aspects.hm.provides.pkgs-gui = 
{ pkgs, ... }:
{
home.packages = with pkgs; [
        audacity
    ];
# TODO: make this only load for workstation or audio workstation
}
;}
