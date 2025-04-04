{ 
  nixos-hardware,
  self,
  nixpkgs,
  pkgs,
  lib,
  config,
  ... 
}: 

let flakePath = self;
in let 
    # _hardware-configuration     = "${flakePath}/system-config/hardware-configurations/durandal-hardware-configuration.nix";
    # _networking-tailscale       = "${flakePath}/system-config/services/__tailscale.nix";
    # _remote-sunshine            = "${flakePath}/___modules/sunshine.nix";
    # _user-elly                  = "${flakePath}/system-config/users/_elly.nix";
    # _wm-kde                     = "${flakePath}/system-config/window-manager/_kde.nix";
    # linux-crisis-utils          = "${flakePath}/___modules/linux-crisis-utilities.nix";
    # _sops-secrets               = "${flakePath}/system-config/secrets/_sops.nix";

    _common                     = "${flakePath}/system-config/common";
    #impermanence               # See below
    _kde                        = "${flakePath}/system-config/hardware-specific/window-manager/kde";

    _gaming                     = "${flakePath}/system-config/gaming";
    _gaming-handheld            = "${flakePath}/system-config/hardware-specific/gaming-handheld";

    # TODO: pull hardware config into flake
    _hardware-configuration     = "${flakePath}/system-config/hardware-configurations/nire-durandal-hardware-configuration.nix";
    
    _amd-gpu                    = "${flakePath}/system-config/hardware-specific/amd/gpu.nix";
    _zsa-moonlander             = "${flakePath}/system-config/hardware-specific/zsa-moonlander.nix";
    _logitech-g600              = "${flakePath}/system-config/hardware-specific/logitech-g600.nix";

  # TODO: why are these in modules
    _remote-sunshine            = "${flakePath}/___modules/sunshine.nix";
    linux-crisis-utils          = "${flakePath}/___modules/linux-crisis-utilities.nix";
  
  # Impermanence
  #! ! WARNING TO THE UNWARY ! this will erase the / mount point
    replace-root-at-boot-etc    = "${flakePath}/system-config/impermanence/_WARN.impermanence.nix";

in {
  # TODO: bring most of these back into the durandal configuration to better follow community conventions
  # TODO: start with linux-defaults next time
    imports = [
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd

        _common
        _gaming
        _kde

        _hardware-configuration
        _amd-gpu
        _zsa-moonlander
        _logitech-g600

      # Hardware
        _hardware-configuration
      
      # TODO: Modules? why
        _remote-sunshine
        linux-crisis-utils  # optional

      # impermanence
      # ____________________________________________________ 
      # |- /!!\ WARN: this will delete /root on boot /!!\ -|
      # ----------------------------------------------------
        replace-root-at-boot-etc
    ];
    

  ## Temporary B550 suspend fix pending nixos-hardware update
  # TODO: remove this when https://github.com/NixOS/nixos-hardware/pull/1394 goes through
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x1483", ATTR{power/wakeup}="disabled"
    '';


    #? This determines what to add to /run/current-system/sw, generally defined elsewhere
    environment.pathsToLink = [

    ];
  
  ## hostname
    networking.hostName = "nire-durandal";

    networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  
  ## System packages
    environment.systemPackages = with pkgs; [ # TODO: describe these
      #* System utilities
        bash                        # bash.  ok i guess.
          #? Bash Plugins
            # inshellisense               # menu-complete and auto-suggest
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
        nix-output-monitor          # `nom` nix-output-monitor                  https://github.com/maralorn/nix-output-monitor
        nh                          # nix helper                                https://github.com/viperML/nh
        linuxHeaders                # linux headers
        sops                        # secret management
        tailscale                   # make tailscale command available to users
    ];



  ## nixos stateVersion for this system
  #   don't change this
  #   For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
    system.stateVersion = "23.11"; # Did you read the comment?

}
