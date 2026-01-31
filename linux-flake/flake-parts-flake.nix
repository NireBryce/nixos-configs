{
    nixConfig = {
        # abort-on-warn = true;
        extra-experimental-features = [ "pipe-operators" ];
        # allow-import-from-derivation = false;
    };
    inputs = {
    # Unstable
        nixpkgs.url
          = "github:NixOS/nixpkgs/nixos-unstable";
        # nixpkgs.url
        #     = "github:NixOS/nixpkgs/nixpkgs-unstable"; # TODO: this is a YOLO fix for https://github.com/nix-community/home-manager/issues/5991,  I have already spent too much time on this
    # Darwin
        darwin.url
          = "github:LnL7/nix-darwin";
        darwin.inputs.nixpkgs.follows
          = "nixpkgs";
    # Jovian (steam deck etc)
        jovian.url
          = "github:Jovian-Experiments/Jovian-NixOS";
        jovian.inputs.nixpkgs.follows
          = "nixpkgs";
    # Impermanence
        impermanence.url
          = "github:Nix-community/impermanence";
    # secret management
        sops-nix.url
          = "github:mic92/sops-nix";
        sops-nix.inputs.nixpkgs.follows
          = "nixpkgs";
        # sops-nix.inputs.nixpkgs-stable.follows
        #  = "nixpkgs";
    # Home Manager
        home-manager.url
          = "github:nix-community/home-manager/master";
        # home-manager-unstable.url
        #   = "github:NixOS/nixpkgs/nixos-unstable";
        home-manager.inputs.nixpkgs.follows
          = "nixpkgs";
    # NixOS-Hardware (for machine-specific fixes)
        nixos-hardware.url
          = "github:NixOS/nixos-hardware/master";
    # Musnix
        musnix.url                                  
          = "github:musnix/musnix";
    # populate nix index
        nix-index-database.url                      
          = "github:nix-community/nix-index-database";
        nix-index-database.inputs.nixpkgs.follows 
          = "nixpkgs";
    #Stylix
        # stylix.url
        #   = "github:danth/stylix";
    # import-tree
        import-tree.url 
          = "github:vic/import-tree";
    # flake parts
        flake-parts.url = "github:hercules-ci/flake-parts";

    };

    outputs = {
      self,
      import-tree,
      nixpkgs,
      #nixpkgs-stable,                                         # https://nixos-and-flakes.thiscute.world/nixos-with-flakes/downgrade-or-upgrade-packages
      darwin,
      flake-parts,
      home-manager,
      nixos-hardware,
      nix-index-database,
      musnix,
      jovian,
      impermanence,
      sops-nix,
      ... 
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (top@{ config, withSystem, moduleWithSystem, ... }: { 
      imports = { };

      flake = {
        debug = true;

        inputs = inputs;                               # move inputs into this scope (I think)

        # nire-durandal (workstation) `nh os switch --hostname nire-durandal ~/nixos/` `sudo nixos-rebuild switch --flake .#nire-durandal`
        nixosConfigurations."nire-durandal" = inputs.nixpkgs.lib.nixosSystem {
            specialArgs = inputs;
            modules     = [
              {
                system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
                networking.hostName = "nire-durandal";
                
                imports = 
                let user = "elly"; host = "nire-durandal"; wm = "kde"; cpu = "amd"; gpu = "amd"; 
                in 
                [
                    (import-tree ../misc/util/nix) # utility functions
                    nix-index-database.nixosModules.nix-index
                    ../misc/modules/linux-crisis-utilities.nix
                    (import-tree ./configs/hosts/${host})
                    (import-tree ./configs/system-config/users/${user})
                    (import-tree ./configs/system-config/hw/gpu/${gpu})
                    (import-tree ./configs/system-config/hw/cpu/${cpu})
                    (import-tree ./configs/system-config/common)
                    (import-tree ./configs/system-config/gaming)
                    (import-tree ./configs/system-config/wm/${wm})
                    # impermanence
                    # |- /!!\ WARN: this will delete /root on boot /!!\ -|
                    ./configs/system-config/impermanence/_WARN.impermanence.nix
                ];

              }
            ];
        };
        # `nh home switch --configuration elly-in-nire-durandal ~/nixos/` `home-manager switch --flake .#elly@nire-durandal`
        homeConfigurations."nire-durandal-hm-elly" = home-manager.lib.homeManagerConfiguration {
            pkgs              = import nixpkgs {                  # Home manger requires a pkgs instance
              system = "x86_64-linux";
              config = { allowUnfree = true; };
            };
            extraSpecialArgs  = inputs; # this might need to be = { inherit inputs; }
            modules           = [
                (import-tree ../misc/util/nix) # utility functions
                { 
                  home.stateVersion        = "22.11"; 
                  home.username            = "elly";
                  home.homeDirectory       = "/home/elly";
                }
                (import-tree ./configs/home-manager/user-elly)
            ];
        };
      

        # nire-tenacity (GPD Win Mini 25). `nh os switch --hostname nire-tenacity ~/nixos/` `sudo nixos-rebuild switch --flake .#nire-tenacity`
        nixosConfigurations."nire-tenacity"     = nixpkgs.lib.nixosSystem {
          specialArgs = inputs;                                 # send inputs to modules (is this actually the right description?)
          system      = "x86_64-linux";
          modules = [
              {
                system.stateVersion = "25.05"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
                networking.hostName = "nire-tenacity";
                imports =
                let user = "elly"; host = "nire-tenacity"; wm = "gaming-handheld"; cpu = "amd"; gpu = "amd"; 
                in
                [
                  ../misc/modules/linux-crisis-utilities.nix
                  (import-tree ../misc/util/nix) # utility functions
                  nix-index-database.nixosModules.nix-index
                  jovian.nixosModules.default
                  
                  (import-tree ./configs/hosts/${host})
                  (import-tree ./configs/system-config/users/${user})
                  (import-tree ./configs/system-config/hw/gpu/${gpu})
                  (import-tree ./configs/system-config/hw/cpu/${cpu})
                  (import-tree ./configs/system-config/common)
                  (import-tree ./configs/system-config/gaming)
                  (import-tree ./configs/system-config/wm/${wm})
                  # |- /!!\ WARN: this will delete /root on boot /!!\ -|
                  ./configs/system-config/impermanence/_WARN.impermanence.nix
                ];
              }
          ];
        };

          # `nh home switch --configuration elly@nire-tenacity ~/nixos/` `home-manager switch --flake .#elly@nire-tenacity`
          homeConfigurations."nire-tenacity-hm-elly" = home-manager.lib.homeManagerConfiguration {
              pkgs              = import nixpkgs {                  # Home manger requires a pkgs instance
                system = "x86_64-linux";
                config = { allowUnfree = true; };
              };
              extraSpecialArgs  = inputs;                           # Pass flake inputs to our config
              modules           = [
                  { 
                      home = { 
                        stateVersion        = "22.11"; 
                        username            = "elly";
                        homeDirectory       = "/home/elly";
                      };
                  imports = [ 
                      (import-tree ./configs/home-manager/user-elly)
                  ];
                  }

                  (import-tree ../misc/util/nix) # utility functions
                
              ];
          };
      };
    });

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

