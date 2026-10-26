# Host naming. A host's flake attribute and `networking.hostName` is the base
# hostname, `nire-<x>`. Its tailnet DNS name is `ts-<x>`; the two are different
# names for one machine (wiki/hosts.md). Both rules used to be written out in
# tailnet-hosts.nix and nix-topology-flake.nix, and a third time in
# flake/scripts/reach-host.sh, which only points here.
{ lib }:
rec {
    prefix = "nire-";

    # The base hostnames among some attribute names, e.g.
    #   baseHostnames (builtins.attrNames self.nixosConfigurations
    #                  ++ builtins.attrNames self.darwinConfigurations)
    # Names only: reading the attribute names never forces a host's evaluation.
    baseHostnames = builtins.filter (lib.hasPrefix prefix);

    tailnetName = host: "ts-${lib.removePrefix prefix host}";
}
