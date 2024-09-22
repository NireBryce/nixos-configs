{ 
  nixos-hardware,
  self,
  nixpkgs,
  pkgs,
  ... 
}: 

let flakePath = self;
in let 
  ## window-manager
    nixos-system-defaults       = "${flakePath}/system-config/configuration.nix";
    fixes-b550-suspend          = "${flakePath}/system-config/system-fixes/suspend/_b550m-gpp0-etc.nix";
    hardware-configuration      = "${flakePath}/system-config/hosts/nire-durandal/hardware-configuration.nix";
    networking-firewall         = "${flakePath}/system-config/hosts/nire-durandal/firewall.nix";
    networking-tailscale        = "${flakePath}/system-config/services/__tailscale.nix";
    remote-ssh                  = "${flakePath}/system-config/ssh.nix";
    remote-sunshine             = "${flakePath}/___modules/sunshine.nix";
    user-elly                   = "${flakePath}/system-config/users/elly/_sys.elly.nix";
    pkgs-system                 = "${flakePath}/system-config/hosts/nire-durandal/pkgs-system.nix";
    wm-kde                      = "${flakePath}/system-config/window-manager/_kde.nix";

  #? ! WARNING TO THE UNWARY ! this will erase the / mount point
    replace-root-at-boot-etc    = "${flakePath}/system-config/impermanence/_WARN.impermanence.nix";

in {
  # TODO: bring most of these back into the durandal configuration to better follow community conventions
    imports = [
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd
        # nixos-hardware.nixosModules.gigabyte-b550         # needs to be fixed upstream in nixos-hardware
                                                            #   also need to fix oneshot being in unit instead of the next section
        nixos-system-defaults
        fixes-b550-suspend
        hardware-configuration
        networking-firewall
        networking-tailscale
        remote-ssh
        remote-sunshine
        user-elly
        pkgs-system
        wm-kde

      # impermanence
      # ____________________________________________________ 
      # |- /!!\ WARN: this will delete /root on boot /!!\ -|
      # ----------------------------------------------------
        replace-root-at-boot-etc
    ];

  # TODO: probably deprecated by the nix-index flake import
    nix.nixPath = [                                           # make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
        "nixpkgs=${nixpkgs}"
        "/nix/var/nix/profiles/per-user/root/channels"
    ];
  
  ## console / VTs
    console = {
        keyMap = "us";
        font = "Lat2-Terminus16";
    };
  ## fonts
    fonts.packages = with pkgs; [
        (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Iosevka" "JetBrainsMono" ];})  # be not afraid
    ];
  
  ## hostname
    networking.hostName = "nire-durandal";

  # TODO: turn into its own module.  helps microphone issues, reduces latency
    musnix = {
      enable          = true;
      kernel.realtime = false;  # you shouldn't enable this unless debugging something
      ## ensure realtime processes don't hang the machine
        # das_watchdog.enable = true;
    };

  # TODO: stylix theme config
  # https://danth.github.io/stylix/configuration.htmloverride {argsOverride = {version = "6.6.27";};

  ## Input
    hardware.keyboard.zsa.enable = true;      # zsa keyboard package
    services.ratbagd.enable      = true;      # for piper logitech mouse ctl

  ## SSH
    services.openssh = {
        enable = true;
        settings.PasswordAuthentication = false;
        settings.KbdInteractiveAuthentication = false;
        allowSFTP = false; # Don't set this if you need sftp

        
        extraConfig = ''
            AllowTcpForwarding yes
            X11Forwarding no
            AllowAgentForwarding no
            AllowStreamLocalForwarding no
            AuthenticationMethods publickey
        '';
    };
  
  ## Firewall
    networking.firewall = { 
      enable = true;
    ## TCP
      allowedTCPPorts = [
          22                            # ssh
      ];
      allowedTCPPortRanges = [  
          { from = 1714; to = 1764; }    # kde-connect TCP
      ];
    ## UDP
      allowedUDPPorts = [                            
      ];
      allowedUDPPortRanges = [
          { from = 1714; to = 1764; }   # kde-connect UDP   
      ];
    };
  ## Games
    programs.steam = {
        enable = true;
        remotePlay.openFirewall      = true;  # Open ports in the firewall for Steam Remote Play
        dedicatedServer.openFirewall = true;  # Open ports in the firewall for Source Dedicated Server
        gamescopeSession.enable      = true;  # third party gamescope compositor
    }; 

  ## GPU
    hardware.amdgpu.amdvlk.enable = false;    # disable amdvlk to use radv
    environment.systemPackages = with pkgs; [ # TODO: describe these
        amf-headers
        mesa
        glfw
        dxvk
        vulkan-tools                # vulkan-tools                              https://github.com/KhronosGroup/Vulkan-Tools
        glxinfo                     # glxinfo                                   https://www.khronos.org/opengl/
        clinfo                      # clinfo                                    https://github.com/Oblomov/clinfo
        amdgpu_top                  # amdgpu_top gpu monitor                    https://github.com/Umio-Yasuno/amdgpu_top
    ];
    hardware.graphics.extraPackages = with pkgs; [
      libva-utils
    ];


  ## nixos stateVersion for this system
  #   don't change this
  #   For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
    system.stateVersion = "23.11"; # Did you read the comment?

}


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
