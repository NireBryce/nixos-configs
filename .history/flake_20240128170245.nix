{
# copied from https://guekka.github.io/nixos-server-2/ almost verbatim
# many of the comments are straight from the post
 
 
# what is consumed (previously provided by channels and fetchTarball)
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # (1)
    impermanence.url = "github:Nix-community/impermanence";
  # secret management
    sops-nix = { 
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      # What's up with this follows? sops-nix already depends on nixpkgs, 
      # but it might use a different revision than ours. Making it use our 
      # own has several advantages:
      # - improve consistency
      # - reduce number of evaluations needed
      # 
      # And how do we know if a package has inputs that need to be redirected? 
      # That's the neat thing, we don't. Either we have to look at the upstream 
      # flake.nix, or we can call nix flake info and get a graph
    };
  };


# what will be produced (i.e. the build)
  # { nixpkgs, ... }@inputs: nixpkgs
  #
  # is the same as:
  #
  # inputs: inputs.nixpkgs
  outputs = { nixpkgs, ... }@inputs: { # (2)
    nixosModules = import ./modules/nixos;

    nixosConfigurations."nire-lysithea = { # (3)
      server = nixpkgs.lib.nixosSystem { # (4)
        # packages = nixpkgs.legacyPackages.x86_64-linux;
        specialArgs = inputs; # forward inputs to modules
# Change this when you change host.
        modules = [
          ./nire-lysithea
        ];
      };
    };
  };
}
