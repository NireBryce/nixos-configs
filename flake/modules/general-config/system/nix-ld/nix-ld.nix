# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, ... }:
{
    nixos = {
        # nix-ld, needed for VSCode remote connection, etc
        programs.nix-ld.enable = lib.mkDefault true;
    };
}
