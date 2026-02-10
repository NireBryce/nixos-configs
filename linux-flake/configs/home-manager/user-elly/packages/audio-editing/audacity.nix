# desc = "Audacity audio editor";
{ den.bundles.hm.audio-edit =
{ pkgs, ... }:
{
home.packages = with pkgs; [
        audacity
    ];
# TODO: make this only load for workstation or audio workstation
}
;}
