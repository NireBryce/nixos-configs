{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # 26.11 -- the release this flake's nixpkgs is actually pinned to
        # (checked against nixosConfigurations.nire-tenacity.config.system.
        # nixos.release), not copied from durandal/tenacity's older value.
        # Those two keep 23.11/25.05 because stateVersion pins option defaults
        # to whatever release a host's data was first created under and is
        # never bumped after the fact; cube has no data yet (not installed --
        # see cube-configuration.nix), so it starts on the current release
        # rather than inheriting durandal's, same reasoning as testbed and
        # lego.
        flake.modules.nixos.${moduleName} = {
            system.stateVersion = lib.mkDefault "26.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        };
}
