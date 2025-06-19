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
  
  # flake-parts
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-lib.follows = "nixpkgs";
  # import-tree flake-parts util
    import-tree.url = "github:vic/import-tree";
    
  };

  outputs = {
    self,
    flake-parts,
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
  flake-parts.lib.mkFlake { inherit inputs; } (top@{ config, withSystem, moduleWithSystem, ... }: {
    debug = true;
    imports = [ 
    # Optional: use external flake logic, e.g.
    #     inputs.foo.flakeModules.default

    ] ;
    systems = [ 
    # Systems for which you want to build the `perSystem` attributes
      "x86_64-linux"
      "aarch64-darwin"
    ];
    perSystem = { ... }: {
      # Recommended: Move all package definitions here.
      #     e.g. (assuming you have a nixpkgs input)
      #     packages.foo = pkgs.callPackage ./foo/package.nix { };
      #     packages.bar = pkgs.callpackage ./bar/package.nix {
      #         foo = config.packages.foo;
      #     };
    };
    flake = {
  
      overlays    = import ./___overlays {inherit inputs;};
      hardware    = import nixos-hardware;           # needed for something in nixos hardware
      inputs = inputs;                               # move inputs into this scope (I think)
      

      nixosConfigurations."nire-durandal"     = nixpkgs.lib.nixosSystem {
      # nire-durandal (workstation)
      #   `sudo nixos-rebuild switch --flake .#nire-durandal`
      #   `nh os switch --hostname nire-durandal ~/nixos/`
        specialArgs = inputs;
        system      = "x86_64-linux";
        modules     = [
          ./system-config/nire-durandal-configuration.nix
          nix-index-database.nixosModules.nix-index
        ];
      };
      #   `home-manager switch --flake .#elly@nire-durandal`
      #   `nh home switch --configuration elly-in-nire-durandal ~/nixos/`
      homeConfigurations."elly-in-nire-durandal" = home-manager.lib.homeManagerConfiguration {
        pkgs              = import nixpkgs {                  # Home manger requires a pkgs instance
          system = "x86_64-linux";
          config = { allowUnfree = true; };
        };
        extraSpecialArgs  = inputs;                           # Pass flake inputs to our config
        modules           = [
            (inputs.import-tree ./home-manager/plasma-manager)
            (inputs.import-tree ./home-manager/user-elly)
            (inputs.import-tree ./home-manager/window-manager/kde)
            plasma-manager.homeManagerModules.plasma-manager
            {
                home.stateVersion        = "22.11"; 
                home.username            = "elly";
                home.homeDirectory       = "/home/elly";
            }
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
      homeConfigurations."elly-in-nire-tenacity" = home-manager.lib.homeManagerConfiguration {
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
    };


    # _module.args.rootPath = ./.;
  });
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

