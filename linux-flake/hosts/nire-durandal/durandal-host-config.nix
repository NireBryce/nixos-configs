# Host aspect for nire-durandal and user aspect for elly.
#
# TRADEOFF — den.resolve + dynamic includes:
#   Every top-level "root" aspect (one per host, one per user) must be listed
#   in the removeAttrs exclusion list below. Leaf aspects (gaming, sound,
#   wayland, …) are picked up automatically and never need to be touched here.
#
#   Adding a new host or user means:
#     1. Declare its root aspect in its own host file (like this one).
#     2. Add its aspect name to the removeAttrs call in every other host/user
#        file so it isn't accidentally pulled into unrelated configs.
#
#   Forgetting step 2 causes cross-contamination: host A's aspect gets resolved
#   into host B's NixOS config, and vice versa.
{ inputs, config, ... }:
{
  flake.nixosConfigurations."nire-durandal" = inputs.self.lib.mkNixos "x86_64-linux" "nire-durandal";

  # Dynamic includes: every aspect except the root aggregators is pulled in.
  # resolve { class = "nixos"; }     only collects the .nixos side.
  # resolve { class = "homeManager"; } only collects the .homeManager side.
  # Aspects that only define one class are silently ignored when resolving the other.
  #
  # ADD NEW HOSTS / USERS HERE — see tradeoff note at the top of this file.
  den.aspects."nire-durandal".includes =
    builtins.attrNames (removeAttrs config.den.aspects [ "nire-durandal" "elly" ]);

  den.aspects."nire-durandal".nixos =
    { nix-index-database, ... }:
    {
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      networking.hostName = "nire-durandal";

      imports = [
        nix-index-database.nixosModules.nix-index
        (inputs.import-tree ./hw-conf)
        (inputs.import-tree ./fixes)
      ];
    };

  # elly's user aspect — root aggregator for home-manager.
  # The stub homeManager module is required so den recognises this as a
  # valid aspect with a homeManager class; the actual config lives in
  # configs/home-manager/user-elly/ and is pulled in via includes above.
  den.aspects.elly.includes =
    builtins.attrNames (removeAttrs config.den.aspects [ "nire-durandal" "elly" ]);

  den.aspects.elly.homeManager = { ... }: { };
}
