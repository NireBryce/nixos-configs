{
  nixConfig = {
    # abort-on-warn = true;
    extra-experimental-features = [ "pipe-operators" ];
    # allow-import-from-derivation = false;
  };
  inputs = {
  # 23.11
    # nixpkgs-stable.url                          = "github:NixOS/nixpkgs/nixos-23.11";
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
  
  # import-tree
    import-tree.url = "github:vic/import-tree";
    
  };

  outputs = {
    self,
    import-tree,
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
    ...
  } @ inputs:
  {
    debug = true;
    overlays    = import ./___overlays {inherit inputs;};
    hardware    = import nixos-hardware;           # needed for something in nixos hardware
    inputs = inputs;                               # move inputs into this scope (I think)
    

    # nire-durandal (workstation)
    #   `sudo nixos-rebuild switch --flake .#nire-durandal`
    #   `nh os switch --hostname nire-durandal ~/nixos/`
    nixosConfigurations."nire-durandal"     = 
        inputs.nixpkgs.lib.nixosSystem 
    {
      # Use specialArgs permits use in `imports`.
      # Note: if you publish modules for reuse, do not rely on specialArgs, but
      # on the flake scope instead. See also https://flake.parts/define-module-in-separate-file.html
        specialArgs = {
            inherit inputs;
        };
        modules     = [
            ./hosts/nire-durandal-configuration.nix
            ./___modules/linux-crisis-utilities.nix
            nix-index-database.nixosModules.nix-index
        ];
    };
    #   `home-manager switch --flake .#elly@nire-durandal`
    #   `nh home switch --configuration elly-in-nire-durandal ~/nixos/`
    homeConfigurations."nire-durandal-hm-elly" = home-manager.lib.homeManagerConfiguration {
        pkgs              = import nixpkgs {                  # Home manger requires a pkgs instance
          system = "x86_64-linux";
          config = { allowUnfree = true; };
        };
        extraSpecialArgs  = {
            inherit inputs;
        };
        modules           = [
            { imports = [ 
                (inputs.import-tree ./home-manager/plasma-manager)
                (inputs.import-tree ./home-manager/user-elly)
                (inputs.import-tree ./home-manager/window-manager/kde)
              ];
              home.stateVersion        = "22.11"; 
              home.username            = "elly";
              home.homeDirectory       = "/home/elly";
            }
            plasma-manager.homeManagerModules.plasma-manager
        ];
    };
  

  # nire-tenacity (GPD Win Mini 25)
    # `sudo nixos-rebuild switch --flake .#nire-tenacity`
    # `nh os switch --hostname nire-tenacity ~/nixos/`
    nixosConfigurations."nire-tenacity"     = nixpkgs.lib.nixosSystem {
      specialArgs = inputs;                                 # send inputs to modules (is this actually the right description?)
      system      = "x86_64-linux";
      modules     = [
        ./hosts/nire-tenacity-configuration.nix
        ./___modules/linux-crisis-utilities.nix
        nix-index-database.nixosModules.nix-index
        # TODO: stylix
        # jovian.nixosModules.jovian
        jovian.nixosModules.default
      ];
    };
  # `home-manager switch --flake .#elly@nire-tenacity`
  # `nh home switch --configuration elly@nire-tenacity ~/nixos/`
    homeConfigurations."nire-tenacity-hm-elly" = home-manager.lib.homeManagerConfiguration {
      pkgs              = import nixpkgs {                  # Home manger requires a pkgs instance
        system = "x86_64-linux";
        config = { allowUnfree = true; };
      };
      extraSpecialArgs  = inputs;                           # Pass flake inputs to our config
      modules           = [
          { imports = [ 
                (inputs.import-tree ./home-manager/plasma-manager)
                (inputs.import-tree ./home-manager/user-elly)
                (inputs.import-tree ./home-manager/window-manager/kde)
              ];
              home.stateVersion        = "22.11"; 
              home.username            = "elly";
              home.homeDirectory       = "/home/elly";
          }
          plasma-manager.homeManagerModules.plasma-manager
        
      ];
    };
  };


  # _module.args.rootPath = ./.;
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

