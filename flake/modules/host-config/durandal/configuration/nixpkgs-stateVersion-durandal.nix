# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    nixos = {
        system.stateVersion = lib.mkDefault "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    };
}
