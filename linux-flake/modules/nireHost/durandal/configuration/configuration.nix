{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        nixpkgs.hostPlatform = "x86_64-linux";
        networking.hostName = "nire-durandal"; # can maybe get rid of this with den.provides.hostname doing the work
    };
}
