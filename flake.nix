# copied from https://guekka.github.io/nixos-server-2/ almost verbatim
# many of the comments are straight from the post
{
  inputs = {
    # 23.11
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    # Unstable
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Impermanence
    impermanence.url = "github:Nix-community/impermanence";
    # secret management
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
    };
  };

  # { nixpkgs, ... }@inputs: nixpkgs
  # is the same as:
  # inputs: inputs.nixpkgs

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: {
    nixosModules = import ./_common/_modules;
    system = "x86_64-linux";

    nixosConfigurations."nire-durandal" = nixpkgs.lib.nixosSystem {
      specialArgs = inputs; # forward inputs to modules
      modules = [
        ./nire-durandal
        # ./home-manager-stopgap.nix
      ];
    };
    homeConfigurations."elly@nire-durandal" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        # Home manger requires a pkgs instance
        system = "x86_64-linux";
        config = {
          allowUnfree = true;
        };
      };
      extraSpecialArgs = {inherit inputs;}; # Pass flake inputs to our config
      modules = [
        ./home-manager/home.nix
        ./home-manager/nire-durandal

        # Host Specific configs
        ./home-manager/nire-durandal/_hm.nire-durandal.nix
      ];
    };

    nixosConfigurations."nire-lysithea" = nixpkgs.lib.nixosSystem {
      # (3)
      specialArgs = inputs;
      system = "x86_64-linux";
      modules = [
        ./nire-lysithea
        # ./home-manager-stopgap.nix
      ];
    };
    homeConfigurations."elly@nire-lysithea" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs; # Home-manager requires 'pkgs' instance
      extraSpecialArgs = {inherit inputs;}; # Pass flake inputs to our config
      modules = [
        ./home-manager/home.nix

        # Host Specific configs
        ./home-manager/nire-lysithea/custom.nix
      ];
    };
    nixosConfigurations."nire-galatea" = nixpkgs.lib.nixosSystem {
      # (3)
      specialArgs = inputs;
      system = "x86_64-linux";
      modules = [
        ./nire-galatea
        #./home-manager-stopgap.nix
      ];
    };
    homeConfigurations."elly@nire-galatea" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs; # Home-manager requires 'pkgs' instance
      extraSpecialArgs = {inherit inputs;}; # Pass flake inputs to our config
      modules = [
        ./home-manager/home.nix

        # Host Specific configs
        ./home-manager/nire-galatea/custom.nix
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

