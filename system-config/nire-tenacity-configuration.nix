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
    # TODO: do nix automatic garbage collection https://www.youtube.com/watch?v=uS8Bx8nQots

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
    ];

  # don't change this without reading about it
    system.stateVersion = "25.05"; # Did you read the comment?
}
