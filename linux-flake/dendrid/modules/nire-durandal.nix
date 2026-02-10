{
  # host aspect
  den.aspects.nire-durandal = {
    # host NixOS configuration
    nixos = { import-tree, nix-index-database, ... }:{
      nixpkgs.hostPlatform = "x86_64-linux";
      system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      networking.hostName = "nire-durandal";
      imports = [ 
        nix-index-database.nixosModules.nix-index
        (import-tree ./configs)
        ../misc/modules/linux-crisis-utilities.nix
        ./configs/system-config/impermanence/_WARN.impermanence.nix
      ];
    };

    # host provides default home environment for its users
    homeManager = { pkgs, ... }: {
      home.packages = [ pkgs.vim ];
    };
  };
}
