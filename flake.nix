{
  inputs = {
  # 23.11
    nixpkgs-stable.url                          = "github:NixOS/nixpkgs/nixos-23.11";
  # Unstable
    nixpkgs.url                                 = "github:NixOS/nixpkgs/nixos-unstable";
  # Darwin
    nix-darwin.url                              = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows           = "nixpkgs";

  # Impermanence
    impermanence.url                            = "github:Nix-community/impermanence";

  # secret management
    sops-nix.url                                = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows             = "nixpkgs";
    sops-nix.inputs.nixpkgs-stable.follows      = "nixpkgs";

  # Home Manager
    home-manager.url                            = "github:nix-community/home-manager/master";
    home-manager-unstable.url                   = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows         = "nixpkgs";
  # NixOS-Hardware (for machine-specific fixes)
    nixos-hardware.url                          = "github:NixOS/nixos-hardware/master";
    # nixos-hardware-b550-stopgap.url             = "github:NixOS/nixos-hardware/master/gigabyte";  # TODO: fix flake.nix on nixos-hardware 

  # Musnix
    musnix.url                                  = "github:musnix/musnix";

  # populate nix index
    nix-index-database.url                      = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows   = "nixpkgs";


  #Stylix
    # stylix.url                                  = "github:danth/stylix";

    
    
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,                                         # https://nixos-and-flakes.thiscute.world/nixos-with-flakes/downgrade-or-upgrade-packages
    nix-darwin,
    home-manager,
    nixos-hardware,
    nix-index-database,
    # nixos-hardware-b550-stopgap,                          # TODO: fix flake.nix on nixos-hardware repo
    musnix,
    ...
  } @ inputs: 
  {
    
       
    
    # Reusable nixos modules you might want to export
    nixosModules    = import ./___modules;   # These are usually stuff you would upstream into nixpkgs
    # homeManagerModules = import ./modules/home-manager

    overlays        = import ./___overlays {inherit inputs;};
    hardware        = import nixos-hardware;

  # nire-durandal (workstation)
  # `sudo nixos-rebuild switch --flake .#nire-durandal`
  # `nh os switch --hostname nire-durandal ~/nixos/`
    nixosConfigurations."nire-durandal"     = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;     # send inputs to modules (is this actually the right description?)
      system      = "x86_64-linux";
      modules     = [
        ./system-config/hosts/nire-durandal/_host.nire-durandal.config.nix
        nix-index-database.nixosModules.nix-index
        inputs.musnix.nixosModules.musnix
        # inputs.nixos-hardware.nixosModules.b550 # TODO: fix flake on nixos-hardware repo
        # inputs.stylix.nixosModules.stylix
        # TODO: stylix
      ];
    };
  # `home-manager switch --flake .#elly@nire-durandal`
  # `nh home switch --configuration elly@nire-durandal ~/nixos/`
    homeConfigurations."elly@nire-durandal" = home-manager.lib.homeManagerConfiguration {
      pkgs              = import nixpkgs {              # Home manger requires a pkgs instance
        system = "x86_64-linux";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = inputs;                       # Pass flake inputs to our config
      modules           = [
        ./home-manager/users/elly/nire-durandal/__hm.elly-nire-durandal.nix  # Elly home manager config
      ];
    };
  
  # nire-lysithea (macbook)
  # TODO: FIXME `sudo nixos-rebuild switch --flake .#nire-durandal`
  # TODO: FIXME `nh os switch --hostname nire-durandal ~/nixos/`
    darwinConfigurations."nire-lysithea"     = nix-darwin.lib.darwinSystem {
      specialArgs = inputs;     # send inputs to modules (is this actually the right description?)
      system      = "aarch64-darwin";
      modules     = [
        ./system-config/hosts/nire-lysithea/_host.nire-lysithea.config.nix
        nix-index-database.nixosModules.nix-index

        # inputs.stylix.nixosModules.stylix
        # TODO: stylix
      ];
    # Expose the package set, including overlays, for convenience.
    # TODO: fixme
      # darwinPackages = self.darwinConfigurations."nire-lysithea".pkgs;
    };
    
  # TODO: fixme `home-manager switch --flake .#elly@nire-durandal`
  # TODO: fixme `nh home switch --configuration elly@nire-durandal ~/nixos/`
    homeConfigurations."elly@nire-lysithea" = home-manager.darwinModules.home-manager {
      pkgs              = import nixpkgs {              # Home manger requires a pkgs instance
        system = "aarch64-darwin";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = inputs;                       # Pass flake inputs to our config
      modules           = [
        ./home-manager/users/elly/nire-lysithea/__hm.elly-nire-lysithea.nix  # Elly home manager config
      ];
      useGlobalPkgs = true;
      useUserPackages = true; 
      users.users.elly.home = "/Users/elly";
    };

  # nire-galatea (thinkpad)
  # `sudo nixos-rebuild switch --flake .#nire-galatea`
  # `nh os switch --hostname nire-galatea ~/nixos/`
    nixosConfigurations."nire-galatea"     = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;     # send inputs to modules (is this true?)
      system      = "x86_64-linux";
      modules     = [
        ./system-config/hosts/nire-galatea/_host-nire-galatea.config.nix
        nix-index-database.nixosModules.nix-index
        
      ];
    };
  # `home-manager switch --flake .#elly@nire-galatea`
  # `nh home switch --configuration elly@nire-galatea ~/nixos/`
    homeConfigurations."elly@nire-galatea" = home-manager.lib.homeManagerConfiguration {
      pkgs              = import nixpkgs {              # Home manger requires a pkgs instance
        system = "x86_64-linux";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = inputs;                       # Pass flake inputs to our config
      modules           = [
        ./home-manager/users/elly/nire-galatea/__hm.elly-nire-galatea.nix  # Elly's home manager config
      ];
    };
  };
}


# nire-galatea
  #   nixosConfigurations."nire-galatea"      = nixpkgs.lib.nixosSystem {
  #     specialArgs = inputs;
  #     system = "x86_64-linux";
  #     modules = [
  #       ./0H2-nire-galatea
  #       nixos-hardware.nixosModules.lenovo-thinkpad-x270
  #     ];
  #   };
  #   homeConfigurations."elly@nire-galatea"  = home-manager.lib.homeManagerConfiguration {
  #     pkgs              = import nixpkgs {          # Home-manager requires 'pkgs' instance
  #       system = "x86_64-linux";
  #       config = { allowUnfree = true; };
  #     };
  #     extraSpecialArgs  = {inherit inputs;};        # Pass flake inputs to our config
  #     modules           = [
  #       # ./0U1-elly/home-manager/0U1h2-nire-galatea.nix
  #     ];
  #   };

  # # nire-lysithea
  #   nixosConfigurations."nire-lysithea"     = nixpkgs.lib.nixosSystem {
  #     specialArgs = inputs;
  #     system = "x86_64-linux";
  #     modules = [
  #       # ./0H3-nire-lysithea
  #     ];
  #   };
  #   homeConfigurations."elly@nire-lysithea" = home-manager.lib.homeManagerConfiguration {
  #     pkgs              = import nixpkgs {          # Home-manager requires 'pkgs' instance
  #       system = "x86_64-linux";
  #       config = { allowUnfree = true; };
  #     };
  #     extraSpecialArgs  = {inherit inputs;};        # Pass flake inputs to our config
  #     modules           = [
  #       # ./0U1-elly/0U1h3-nire-lysithea.nix
  #     ];
  #   };


################################################################################
# NOTE FOR ZSH
# https://www.reddit.com/r/NixOS/comments/1539s44/using_flakes_for_configurationnix/
# https://stackoverflow.com/questions/12303805/oh-my-zsh-hash-pound-symbol-bad-pattern-or-match-not-found/57380936#57380936
# this fixes nix-flakes
#   disable -p '#'
# otherwise `nixos-rebuild --flake .#hostname` will not get evaluated correctly.
################################################################################

