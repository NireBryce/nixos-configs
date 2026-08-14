{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # 26.11 -- the release this flake's nixpkgs is actually pinned to, same
        # reasoning as testbed's: not yet installed, no existing data to pin a
        # release for, so start on the current release rather than inheriting
        # durandal's 23.11 or tenacity's 25.05.
        flake.modules.nixos.${moduleName} = {
            system.stateVersion = lib.mkDefault "26.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        };
}
