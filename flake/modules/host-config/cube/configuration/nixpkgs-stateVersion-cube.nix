# Module file: named after this file; why it looks this way: wiki/module-files.md
{ lib, ... }:
{
    # 26.05 -- NOT this flake's own 26.11 pin (checked against
    # nixosConfigurations.nire-tenacity.config.system.nixos.release), and
    # not the "starts on the current release, no data yet" 26.11 this file
    # used to say either. This host was installed by hand off the stock
    # NixOS live ISO before this flake was ever pointed at it (`nixos-version`
    # on the real machine: 26.05.7813.0dd31db7e6db), and its own
    # /etc/nixos/configuration.nix already recorded
    # `system.stateVersion = "26.05"` from that install. stateVersion pins
    # option defaults to whatever release a host's data was first created
    # under and is never bumped after the fact -- see durandal's/tenacity's
    # own 23.11/25.05 for the same reasoning -- so this has to match what
    # /etc/nixos already committed to, not this flake's nixpkgs pin.
    nixos = {
        system.stateVersion = lib.mkDefault "26.05"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    };
}
