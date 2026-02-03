# desc = "Audacity audio editor";
{ flake.modules.homeManager.packages.audioEditing.audacity =
{ pkgs, ... }:
{
home.packages = with pkgs; [
        audacity
    ];
# TODO: make this only load for workstation or audio workstation
}
;}
