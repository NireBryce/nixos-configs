# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    # 4, an integer -- `system.stateVersion = mkOption { type =
    # types.ints.between 1 config.system.maxStateVersion; }` in nix-darwin's
    # own modules/system/version.nix, not a "YY.MM" string like the NixOS
    # hosts use. Carried over from macos-old/nire-lysithea-configuration.nix
    # rather than defaulted to the current max, for the same reason NixOS's
    # stateVersion is never bumped casually: it pins which release's option
    # defaults apply to stateful data already on disk.
    darwin = {
        system.stateVersion = lib.mkDefault 4; # Don't change.
    };
}
