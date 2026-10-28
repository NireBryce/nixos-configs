# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    nixos = {
        system.stateVersion = lib.mkDefault "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    };
}
