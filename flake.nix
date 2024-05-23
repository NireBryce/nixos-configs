{
  inputs = {
    # 23.11
    nixpkgs-stable.url                      = "github:NixOS/nixpkgs/nixos-23.11";
    # Unstable
    nixpkgs.url                             = "github:NixOS/nixpkgs/nixos-unstable";

    # Impermanence
    impermanence.url                        = "github:Nix-community/impermanence";

    # secret management
    sops-nix.url                            = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows         = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows  = "nixpkgs";

    # Home Manager
    home-manager.url                        = "github:nix-community/home-manager/master";
    home-manager-unstable.url               = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows     = "nixpkgs";

    # NixOS-Hardware (for machine-specific fixes)
    nixos-hardware.url                      = "github:NixOS/nixos-hardware/master";
    # nixos-hardware-b550-stopgap.url         = "github:NixOS/nixos-hardware/master/gigabyte";  # TODO: fix flake.nix on nixos-hardware 

    # Musnix
    musnix.url                              = "github:musnix/musnix";

    #Stylix
    # stylix.url                              = "github:danth/stylix";

    # Haumea (Folder structure for imports)
    # haumea.url                              = "github:nix-community/haumea";
    # haumea.inputs.nixpkgs.follows           = "nixpkgs";


    
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    nixos-hardware,
    # nixos-hardware-b550-stopgap, # TODO: fix flake.nix on nixos-hardware repo
    musnix,
    ...
  } @ inputs: 
  {
    
       
    
    # Reusable nixos modules you might want to export
    nixosModules = import ./system/_modules;   # These are usually stuff you would upstream into nixpkgs
    # homeManagerModules = import ./modules/home-manager

    overlays     = import ./_overlays {inherit inputs;};
    hardware     = import nixos-hardware;

  # nire-durandal
  # `sudo nixos-rebuild switch --flake .#nire-durandal`
    nixosConfigurations."nire-durandal"     = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;     # send inputs to modules
      system      = "x86_64-linux";
      modules     = [
        ./_hosts/nire-durandal
        inputs.musnix.nixosModules.musnix
        # inputs.nixos-hardware.nixosModules.b550 # TODO: fix flake on nixos-hardware repo
        # inputs.stylix.nixosModules.stylix
      ];
    };
  # `home-manager switch --flake .#elly@nire-durandal`
    homeConfigurations."elly@nire-durandal" = home-manager.lib.homeManagerConfiguration {
      pkgs              = import nixpkgs {          # Home manger requires a pkgs instance
        system = "x86_64-linux";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = inputs;       # Pass flake inputs to our config
      modules           = [
        # ./home-manager/home.nix       # TODO: put this back once you're importing more modules here
        ./home-manager/nire-durandal
      ];
    };

  # nire-lysithea
    nixosConfigurations."nire-lysithea"     = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;
      system = "x86_64-linux";
      modules = [
        ./_hosts/nire-lysithea
      ];
    };
    homeConfigurations."elly@nire-lysithea" = home-manager.lib.homeManagerConfiguration {
      pkgs              = import nixpkgs {          # Home-manager requires 'pkgs' instance
        system = "x86_64-linux";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = {inherit inputs;};        # Pass flake inputs to our config
      modules           = [
        ./home-manager/home.nix
        ./home-manager/nire-lysithea
      ];
    };

  # nire-galatea
    nixosConfigurations."nire-galatea" = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;
      system = "x86_64-linux";
      modules = [
        ./_hosts/nire-galatea
      ];
    };
    homeConfigurations."elly@nire-galatea" = home-manager.lib.homeManagerConfiguration {
      pkgs              = import nixpkgs {          # Home-manager requires 'pkgs' instance
        system = "x86_64-linux";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = {inherit inputs;};        # Pass flake inputs to our config
      modules           = [
        ./home-manager/home.nix
        ./home-manager/nire-galatea
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

