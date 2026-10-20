# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, ... }:
{
    darwin = {
        nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
    };
}
