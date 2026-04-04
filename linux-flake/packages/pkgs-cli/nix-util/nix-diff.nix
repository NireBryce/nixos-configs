# desc = "diff nix code";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nix-diff
    ];
}
