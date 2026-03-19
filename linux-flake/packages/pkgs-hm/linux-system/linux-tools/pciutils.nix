# desc = "lspci";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        pciutils
    ];
}

