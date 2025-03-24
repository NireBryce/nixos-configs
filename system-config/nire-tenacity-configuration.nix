{ 
  nixos-hardware,
  self,
  pkgs,

  ... 
}: 
  
let flakePath = self;
in let 
    _font                       = "${flakePath}/system-config/common";
    #impermanence               # See below
    _networking                 = "${flakePath}/system-config/common/networking";
    _nix                        = "${flakePath}/system-config/common/nix";
    _secrets                    = "${flakePath}/system-config/common/secrets";
    _services                   = "${flakePath}/system-config/common/services";
    _shells                     = "${flakePath}/system-config/common/shells";
    _sound                      = "${flakePath}/system-config/common/sound";
    _ssh                        = "${flakePath}/system-config/common/ssh";
    _system                     = "${flakePath}/system-config/common/system";
    _users                      = "${flakePath}/system-config/common/users";
    _window-manager             = "${flakePath}/system-config/common/window-manager";
    _xdg                        = "${flakePath}/system-config/common/xdg";

    _gaming                     = "${flakePath}/system-config/gaming";
    _gaming-handheld            = "${flakePath}/system-config/hardware-specific/gaming-handheld";

    _hardware-configuration     = "${flakePath}/system-config/hardware-configurations/tenacity-hardware-configuration.nix";
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
    imports = [
      # <nixos-hardware> modules
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd

      # Common
        _font
        #impermanence               # See below
        _networking
        _nix
        _secrets
        _services
        _shells
        _sound
        _ssh
        _system
        _users
        _window-manager
        _xdg

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
    
  #? This determines what to add to /run/current-system/sw, generally defined elsewhere
    environment.pathsToLink = [

    ];

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
