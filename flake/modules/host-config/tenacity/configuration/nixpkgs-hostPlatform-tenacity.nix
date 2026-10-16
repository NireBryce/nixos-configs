# Module file: named after this file; why it looks this way: wiki/module-files.md
{ lib, ... }:
{
    nixos = {
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
