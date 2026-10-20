# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, ... }:
{
    nixos = {
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
