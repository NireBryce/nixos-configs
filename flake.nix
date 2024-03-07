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
      # packages = nixpkgs.legacyPackages.x86_64-linux;
      specialArgs = inputs;
      modules = [
        ./nire-durandal
      ];
    };

    nixosConfigurations."nire-lysithea" = nixpkgs.lib.nixosSystem { # (3)
      # packages = nixpkgs.legacyPackages.x86_64-linux;
      specialArgs = inputs; # forward inputs to modules
      modules = [
        ./nire-lysithea
      ];
    };
    nixosConfigurations."nire-galatea" = nixpkgs.lib.nixosSystem { # (3)
      # packages = nixpkgs.legacyPackages.x86_64-linux;
      specialArgs = inputs; # forward inputs to modules
      modules = [
        ./nire-galatea
      ];
    };
  };
}
################################################################################
# NOTE FOR ZSH
# https://www.reddit.com/r/NixOS/comments/1539s44/using_flakes_for_configurationnix/
# https://stackoverflow.com/questions/12303805/oh-my-zsh-hash-pound-symbol-bad-pattern-or-match-not-found/57380936#57380936
# this fixes nix-flakes
#   disable -p '#'
# otherwise `nixos-rebuild --flake .#hostname` will not get evaluated correctly.
################################################################################


