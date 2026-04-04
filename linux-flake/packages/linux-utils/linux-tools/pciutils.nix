{ pkgs, ... }:
{
# lspci
    home.packages = with pkgs; [
        pciutils
    ];
}

