{ config, lib, inputs, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

    # Only the attribute names are read, which never forces a host's
    # evaluation -- same derivation as tailnet-hosts.nix.
    nixosHosts  = builtins.filter (lib.hasPrefix "nire-")
        (builtins.attrNames config.flake.nixosConfigurations);
    darwinHosts = builtins.filter (lib.hasPrefix "nire-")
        (builtins.attrNames config.flake.darwinConfigurations);

    tailnetName = host: "ts-${lib.removePrefix "nire-" host}";

    tailnetInterface = name: {
        network   = "tailnet";
        virtual   = true;
        addresses = [ name ];
    };
in {
    # Flake-parts half: adds `flake.topology.<system>` and
    # `perSystem.topology.{nixosConfigurations,modules,pkgs}`. Render with
    #   nix build .#topology.x86_64-linux.config.output
    # nixosConfigurations defaults to every host whose config has a
    # `topology` option, i.e. every host that imports the NixOS half below.
    imports = [ inputs.nix-topology.flakeModule ];

    # What goes in here is limited to what this repo already states in the
    # open: the host roster, the `ts-<x>` naming rule, and the backup target
    # restic.nix names. Anything that would be new information about the
    # network (subnets, upstream devices, addresses) stays out.
    perSystem = _: {
        topology.modules = [
            {
                networks.tailnet.name = "Tailnet";

                nodes = lib.mkMerge [
                    # NixOS hosts already exist as nodes (the host's own
                    # topology module defines them); only the interface is added.
                    (lib.genAttrs nixosHosts (host: {
                        interfaces.tailscale0 = tailnetInterface (tailnetName host);
                    }))

                    # Not NixOS configurations, so nothing defines them yet.
                    (lib.genAttrs darwinHosts (host: {
                        name       = host;
                        deviceType = "device";
                        interfaces.tailscale0 = tailnetInterface (tailnetName host);
                    }))

                    {
                        ts-hive = {
                            name       = "ts-hive";
                            deviceType = "device";
                            interfaces.tailscale0 = tailnetInterface "ts-hive";
                        };
                    }
                ];
            }
        ];
    };

    # NixOS half: lets each host describe itself. Extractors fill in most of
    # it from the existing config (interfaces, services, tailscale, etc.).
    flake.modules.nixos.${moduleName} = { ... }: {
        imports = [ inputs.nix-topology.nixosModules.default ];
    };
}
