# desc = "nix man pages, kinda";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        manix
    ];
}

