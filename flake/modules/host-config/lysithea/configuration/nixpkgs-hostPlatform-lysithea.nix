# Module file: named after this file; why it looks this way: wiki/module-files.md
{ lib, ... }:
{
    darwin = {
        nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
    };
}
