{ 
  nixos-hardware,
  self,
  pkgs,

  ... 
}: 
  
let flakePath = self;
    
in let 
    _common                     = "${flakePath}/system-config/common";
    #impermanence               # See below
    

    _gaming                     = "${flakePath}/system-config/gaming";
    _gaming-handheld            = "${flakePath}/system-config/hardware-specific/gaming-handheld";

    _hardware-configuration     = "${flakePath}/system-config/hardware-configurations/";
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

        _common
        _gaming
        _gaming-handheld

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
