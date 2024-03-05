# copied from https://guekka.github.io/nixos-server-2/ almost verbatim
# many of the comments are straight from the post
 
{ 
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # (1)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # (1)
    impermanence.url = "github:Nix-community/impermanence";
  # secret management
    sops-nix = { 
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      # What\'s up with this follows? sops-nix already depends on nixpkgs, 
      # but it might use a different revision than ours. Making it use our 
      # own has several advantages:
      # - improve consistency
      # - reduce number of evaluations needed
      # 
      # And how do we know if a package has inputs that need to be redirected? 
      # That\'s the neat thing, we don\'t. Either we have to look at the upstream 
      # flake.nix, or we can call nix flake info and get a graph
    };
  };


  # { nixpkgs, ... }@inputs: nixpkgs
  #
  # is the same as:
  #
  # inputs: inputs.nixpkgs

  outputs = { nixpkgs, ... }@inputs: {
    nixosModules = import ./modules/nixos;

    nixosConfigurations."nire-durandal" = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;
      packages = nixpkgs.legacyPackages.${system};
      modules = [
        ./nire-durandal
      ];
    };

    nixosConfigurations."nire-lysithea" = nixpkgs.lib.nixosSystem { # (3)
      packages = nixpkgs.legacyPackages.${system};
      specialArgs = inputs; # forward inputs to modules
      modules = [
        ./nire-lysithea
      ];
    };
    nixosConfigurations."nire-galatea" = nixpkgs.lib.nixosSystem { # (3)
      packages = nixpkgs.legacyPackages.${system};
      specialArgs = inputs; # forward inputs to modules
      modules = [
        ./nire-galatea
      ];
    };
  };
}

