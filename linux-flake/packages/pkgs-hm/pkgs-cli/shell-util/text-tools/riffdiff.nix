# desc = "per-character in-line diff";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        riffdiff
    ];
}
