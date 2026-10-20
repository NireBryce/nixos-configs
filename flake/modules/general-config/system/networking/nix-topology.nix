# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, inputs, ... }:
{
    # The NixOS half of nix-topology: lets each host describe itself.
    # Extractors fill in most of it from the existing config (interfaces,
    # services, tailscale, etc.). The flake-parts half -- the `topology`
    # output and the tailnet drawn over it -- is nix-topology-flake.nix
    # beside this; they were one file until the move to dirs-as-categories.
    nixos = { config, ... }: {
        imports = [ inputs.nix-topology.nixosModules.default ];

        # The restic extractor prints each backup's `paths` on the card, and a
        # detail section can't be removed, only blanked (which leaves an empty
        # heading). So hide the extracted service and declare one carrying
        # just the name and repository. Only the diagram changes.
        topology.self.services = lib.mkMerge (lib.mapAttrsToList
            (name: cfg: {
                ${name}.hidden = true;
                "${name}-no-paths" = {
                    name = "Restic backup '${name}'";
                    icon = "services.restic";
                    info = lib.mkIf (cfg.repository != null) cfg.repository;
                };
            })
            config.services.restic.backups);
    };
}
