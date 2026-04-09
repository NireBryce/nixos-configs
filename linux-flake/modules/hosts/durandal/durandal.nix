{ inputs, lib, ... }:
let
    provides = {
        configuration = { imports = [ (inputs.import-tree ./_/configuration) ]; };
        fixes         = { imports = [ (inputs.import-tree ./_/fixes) ]; };
        hardware      = { imports = [ (inputs.import-tree ./_/hardware) ]; };
    };
in {
    nireHost.durandal = {
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        nixpkgs.hostPlatform = "x86_64-linux";
        networking.hostName = "nire-durandal"; # can maybe get rid of this with den.provides.hostname doing the work

        provides = provides // {
            all = { includes = lib.attrValues provides; };
        };
    };
}
