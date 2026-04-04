# desc = "Audacity audio editor";
{ pkgs, ... }:
{
home.packages = with pkgs; [
        audacity
    ];
# TODO: make this only load for workstation or audio workstation
}
