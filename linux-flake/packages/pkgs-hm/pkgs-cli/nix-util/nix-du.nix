# desc = "nix-store analysis"; 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nix-du
    ];
}

