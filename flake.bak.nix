{
  inputs = {
  # 23.11
    nixpkgs-stable.url                          = "github:NixOS/nixpkgs/nixos-23.11";
  # Unstable
    # nixpkgs.url                                 = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url                                 = "github:NixOS/nixpkgs/nixpkgs-unstable"; # TODO: this is a YOLO fix for https://github.com/nix-community/home-manager/issues/5991,  I have already spent too much time on this
                                                                                           #* notice that it's nixpkgs.unstable not nixos.unstable 

  # Darwin
    darwin.url                                  = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows               = "nixpkgs";

  # Jovian (steam deck etc)
    jovian.url                                  = "github:Jovian-Experiments/Jovian-NixOS";
    jovian.inputs.nixpkgs.follows               = "nixpkgs";

  # Impermanence
    impermanence.url                            = "github:Nix-community/impermanence";

  # secret management
    sops-nix.url                                = "github:mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows             = "nixpkgs";
    # sops-nix.inputs.nixpkgs-stable.follows      = "nixpkgs";
  # Home Manager
    home-manager.url                            = "github:nix-community/home-manager/master";
    # home-manager-unstable.url                   = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.inputs.nixpkgs.follows         = "nixpkgs";
  # NixOS-Hardware (for machine-specific fixes)
    nixos-hardware.url                          = "github:NixOS/nixos-hardware/master";

  # Musnix
    musnix.url                                  = "github:musnix/musnix";

  # populate nix index
    nix-index-database.url                      = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows   = "nixpkgs";

  # plasma manager
    plasma-manager.url                          = "github:nix-community/plasma-manager";

  #Stylix
    # stylix.url                                  = "github:danth/stylix";
  
    haumea.url = "github:nix-community/haumea/v0.2.2"; #TODO: figure out haumea update schedule
    haumea.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    #nixpkgs-stable,                                         # https://nixos-and-flakes.thiscute.world/nixos-with-flakes/downgrade-or-upgrade-packages
    plasma-manager,
    darwin,
    home-manager,
    nixos-hardware,
    nix-index-database,
    musnix,
    jovian,
    impermanence,
    sops-nix,
    haumea,
    ...
  } @ inputs: 
  {
    overlays    = import ./___overlays {inherit inputs;};
    hardware    = import nixos-hardware;
    inputs = inputs;                               # send inputs to modules (is this actually the right description?)
    
    # nire-durandal (workstation)
    #   `sudo nixos-rebuild switch --flake .#nire-durandal`
    #   `nh os switch --hostname nire-durandal ~/nixos/`
    nixosConfigurations."nire-durandal"     = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;
      system      = "x86_64-linux";
      modules     = [
        ./system-config/nire-durandal-configuration.nix
        nix-index-database.nixosModules.nix-index
        # This lets us flatten 'programs' configs into a single file, I hope.
        
        # nixos-hardware.nixosModules.gigabyte-b550 # TODO: enable this when https://github.com/NixOS/nixos-hardware/pull/1394 goes through
        # inputs.nixos-hardware.nixosModules.b550 # TODO: fix flake on nixos-hardware repo
        
        # inputs.musnix.nixosModules.musnix
        # inputs.stylix.nixosModules.stylix
        
        # TODO: home manager merge
      ];
    };
    #   `home-manager switch --flake .#elly@nire-durandal`
    #   `nh home switch --configuration elly@nire-durandal ~/nixos/`
    homeConfigurations."elly@nire-durandal" = home-manager.lib.homeManagerConfiguration {
      pkgs              = import nixpkgs {                  # Home manger requires a pkgs instance
        system = "x86_64-linux";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = inputs;                           # Pass flake inputs to our config
      modules           = [
        plasma-manager.homeManagerModules.plasma-manager
        ./home-manager/user-elly/home-nire-durandal.nix  # home manager entrypoint
      ];
    };
  

  # nire-tenacity (GPD Win Mini 25)
    # `sudo nixos-rebuild switch --flake .#nire-tenacity`
    # `nh os switch --hostname nire-tenacity ~/nixos/`
    nixosConfigurations."nire-tenacity"     = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;                                 # send inputs to modules (is this actually the right description?)
      system      = "x86_64-linux";
      modules     = [
        ./system-config/nire-tenacity-configuration.nix
        nix-index-database.nixosModules.nix-index
        # TODO: stylix
        # jovian.nixosModules.jovian
        jovian.nixosModules.default
      ];
    };
  # `home-manager switch --flake .#elly@nire-tenacity`
  # `nh home switch --configuration elly@nire-tenacity ~/nixos/`
    homeConfigurations."elly@nire-tenacity" = home-manager.lib.homeManagerConfiguration {
      pkgs              = import nixpkgs {                  # Home manger requires a pkgs instance
        system = "x86_64-linux";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = inputs;                           # Pass flake inputs to our config
      modules           = [
        plasma-manager.homeManagerModules.plasma-manager
        ./home-manager/user-elly/home-nire-tenacity.nix  # home manager entrypoint
      ];
    };


  # nire-lysithea (macbook)
    darwinConfigurations."nire-lysithea"     = darwin.lib.darwinSystem {
      specialArgs = { inherit inputs ; };
      system      = "aarch64-darwin";
      modules     = [
        ./system-config/nire-lysithea-configuration.nix
        # nix-index-database.darwinModules.nix-index
      
        # TODO: stylix
        # inputs.stylix.darwinModules.stylix
        
        home-manager.darwinModules.home-manager 
        {
          home-manager = { 
            users.elly = import ./home-manager/user-elly/home-nire-lysithea.nix;
          };
          users.users.elly.home = "/Users/elly";
        }

        # nix-index-database.hmModules.nix-index
        # { programs.nix-index-database.comma.enable = true; }
        # todo: fix this

      ];
    # Expose the package set, including overlays, for convenience.
    # TODO: fixme
      #  darwinPackages = self.darwinConfigurations."nire-lysithea".pkgs;
    };
  # elly@nire-lysithea
  #  homeConfigurations."elly@nire-lysithea.local" = home-manager.lib.homeManagerConfiguration {
  #     pkgs = import nixpkgs {
  #       system = "aarch64-darwin";
  #       config = { 
  #         allowUnfree = true; 
  #         useGlobalPkgs   = true;
  #         useUserPackages = true; 
  #       };
  #     };
  #     extraSpecialArgs = inputs;
  #     modules = [
  #       ./home-manager/user-elly/home-nire-lysithea.nix     # Elly home manager config
  #       nix-index-database.hmModules.nix-index
  #         { programs.nix-index-database.comma.enable = true; }
  #     ];
      
  #   };

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
        ./home-manager/user-elly/home-nire-galatea.nix  # Elly's home manager config
      ];
    };
  };
}

# NOTE: for nix-index to work with flake installs, you must `nix profile install` something
#   see: https://github.com/nix-community/nix-index/issues/167
#   `nix profile install nixpkgs#hello


################################################################################
# NOTE FOR ZSH
# https://www.reddit.com/r/NixOS/comments/1539s44/using_flakes_for_configurationnix/
# https://stackoverflow.com/questions/12303805/oh-my-zsh-hash-pound-symbol-bad-pattern-or-match-not-found/57380936#57380936
# this fixes nix-flakes
#   disable -p '#'
# otherwise `nixos-rebuild --flake .#hostname` will not get evaluated correctly.
################################################################################

