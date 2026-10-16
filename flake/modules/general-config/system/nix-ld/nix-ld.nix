# Module file: named after this file; why it looks this way: wiki/module-files.md
{ lib, ... }:
{
    nixos = {
        # nix-ld, needed for VSCode remote connection, etc
        programs.nix-ld.enable = lib.mkDefault true;
    };
}
