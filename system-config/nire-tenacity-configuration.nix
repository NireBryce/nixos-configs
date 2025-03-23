{ 
  nixos-hardware,
  self,
  nixpkgs,
  pkgs,
  lib,
  ... 
}: 

#* This defines nire-tenacity's config, a GPD Win Mini 2025
#*   Nixos works pretty much out of the box on it, surprisingly.
#*   
#*   However, common TDP control applications for handhelds aren't quite there yet.

let flakePath = self;
in let 
    _hardware-configuration     = "${flakePath}/system-config/hardware-configurations/tenacity-hardware-configuration.nix";
    _networking-tailscale       = "${flakePath}/system-config/services/__tailscale.nix";
    _remote-sunshine            = "${flakePath}/___modules/sunshine.nix";
    _user-elly                  = "${flakePath}/system-config/users/_elly.nix";
    _wm-kde                     = "${flakePath}/system-config/window-manager/_kde.nix";
    linux-crisis-utils          = "${flakePath}/___modules/linux-crisis-utilities.nix";
    _sops-secrets               = "${flakePath}/system-config/secrets/_sops.nix";
  
  ## hardware bugfixes
    
  #! ! WARNING TO THE UNWARY ! this will erase the / mount point
    replace-root-at-boot-etc    = "${flakePath}/system-config/impermanence/_WARN.impermanence.nix";

in {
  # TODO: bring most of these back into the durandal configuration to better follow community conventions
  # TODO: start with linux-defaults next time
    imports = [
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd
        _sops-secrets
        _hardware-configuration
        _networking-tailscale
        _remote-sunshine
        _user-elly
        _wm-kde 

        linux-crisis-utils  # optional
        # fixes-b550-suspend
      # impermanence
      # ____________________________________________________ 
      # |- /!!\ WARN: this will delete /root on boot /!!\ -|
      # ----------------------------------------------------
        replace-root-at-boot-etc
    ];
    

  ## nix settings
    nix.settings.trusted-users = [ "root" ];
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true;

  # TODO: probably deprecated by the nix-index flake import
    nix.nixPath = [                                           # make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
        "nixpkgs=${nixpkgs}"
        "/nix/var/nix/profiles/per-user/root/channels"
    ];
  
  #? This determines what to add to /run/current-system/sw, generally defined elsewhere
    environment.pathsToLink = [

    ];

  ## Boot
    #? Use the systemd-boot EFI boot loader.
    boot.loader = {
        systemd-boot.enable       = lib.mkDefault true;
        efi.canTouchEfiVariables  = lib.mkDefault true;
    };

  ## console / VTs
    console = {
        keyMap = "us";
        font   = "Lat2-Terminus16";
    };
  

  ## Locale
    i18n.defaultLocale  = lib.mkDefault "en_US.UTF-8";
    time.timeZone       = lib.mkDefault "America/New_York"; 

  ## hostname
    networking.hostName = "nire-tenacity";

  ## Input
    
    

    # TODO: why this DNS
    networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];


  # TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots
  



  ## System packages
    environment.systemPackages = with pkgs; [ # TODO: describe these
      #* System utilities
        bash                        # bash.  ok i guess.
          #? Bash Plugins
            starship                    # theming
            blesh                       # if bash were zsh
        coreutils                   # coreutils
        curl                        # curl
        gcc                         # gcc
        git                         # git
        micro                       # micro
        stdenv                      # stdenv
        wget                        # wget
        zoxide                      # zoxide
        ripgrep                     # ripgrep
        mullvad-vpn                 # mullvad-vpn
        linuxHeaders                # linux headers
        tailscale                   # make tailscale command available to users

      #* GPU-related packages
        

        
        
    ];

  
    

  ## nixos stateVersion for this system
  #   don't change this
  #   For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
    system.stateVersion = "25.05"; # Did you read the comment?

}


## ** Fixes **

## `SteamTinkerLaunch` requires some workarounds, see: https://gist.github.com/jakehamilton/632edeb9d170a2aedc9984a0363523d3

## I think this is deprecated by it being in the flake
  # programs.command-not-found.enable = lib.mkForce false; # conflicts with nix-index-database


## * Notes
  ## Determine where a build is failing if --impure works.
    #? This is a hack and there must be a better way
      # sudo nixos-rebuild dry-build -vvv          --flake .#nire-durandal 2>&1 | tee pure.txt; 
      # sudo nixos-rebuild dry-build -vvv --impure --flake .#nire-durandal 2>&1 | tee impure.txt; 
      # diff -y pure.txt impure.txt
      
  ## ways of overriding kernel
    # boot.kernelPackages = pkgs.linuxPackages_6_9;
    # boot.kernelPackages = pkgs.linux_6_6.override { argsOverride = { version = "6.6.23"; }; };
    # boot.kernelPackages = lib.mkForce pkgs.linuxPackagesFor (pkgs.linux_6_6.override {argsOverride = {version = "6.6.27";};});
    # boot.kernelPackages = lib.mkForce pkgs.linuxKernel.kernels.linux_6_6;
    # boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_6.override {
    #   argsOverride = rec {
    #     src = pkgs.fetchurl {
    #       url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
    #       sha256 = "IA/RGcue8GvO3NtSvgC6RDFj6rFUKVxYMf7ZoSIRqLk=";
    #     };
    #     version = "6.6.23";
    #     modDirVersion = "6.6.23";
    #   };
    # });

  ## musnix:
    # musnix.kernel.packages =  pkgs.linuxPackagesFor (pkgs.linux_6_6.override {
    #   argsOverride = rec {
    #     src = pkgs.fetchurl {
    #       url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
    #       sha256 = "IA/RGcue8GvO3NtSvgC6RDFj6rFUKVxYMf7ZoSIRqLk=";
    #     };
    #     version = "6.6.23";
    #     modDirVersion = "6.6.23";
    #   };
    # });


