# desc = "nix package version diff";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nvd
    ];
}
