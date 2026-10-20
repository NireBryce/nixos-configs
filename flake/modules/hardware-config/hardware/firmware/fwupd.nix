# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, ... }:
{
    nixos = {
        services.fwupd.enable = lib.mkDefault true; # fwupd
    };
}
