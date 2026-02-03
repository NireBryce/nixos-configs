{
    flake.modules.nixos = { import-tree }: {
        nixosConfigurations = {
            "nire-durandal" = import-tree ./configs/hosts/nire-durandal;
            "nire-tenacity" = import-tree ./configs/hosts/nire-tenacity;
        };
    };
}
