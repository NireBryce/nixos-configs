# Module file: named after this file; why it looks this way: wiki/module-files.md
{ lib, ... }:
{
    nixos = {
        services.fwupd.enable = lib.mkDefault true; # fwupd
    };
}
