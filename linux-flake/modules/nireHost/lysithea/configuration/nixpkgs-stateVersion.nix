{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # 4, an integer -- `system.stateVersion = mkOption { type =
        # types.ints.between 1 config.system.maxStateVersion; }` in nix-darwin's
        # own modules/system/version.nix, not a "YY.MM" string like the NixOS
        # hosts use. Carried over from macos-old/nire-lysithea-configuration.nix
        # rather than defaulted to the current max, for the same reason NixOS's
        # stateVersion is never bumped casually: it pins which release's option
        # defaults apply to stateful data already on disk.
        flake.modules.darwin.${moduleName} = {
            system.stateVersion = lib.mkDefault 4; # Don't change.
        };
}
