# Module file: named after this file; why it looks this way: wiki/module-files.md
{ lib, ... }:
{
    nixos = {
        system.stateVersion = lib.mkDefault "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    };
}
