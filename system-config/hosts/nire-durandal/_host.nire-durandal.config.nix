{ 
  nixos-hardware,
  self,
  nixpkgs,
  ... 
}: 

let flakePath = self;
in {
  imports = [
    nixos-hardware.nixosModules.common-cpu-amd
    nixos-hardware.nixosModules.common-gpu-amd
    # nixos-hardware.nixosModules.gigabyte-b550 # needs to be fixed upstream in nixos-hardware
                                                # also need to fix oneshot being in unit instead of the next section
    
    # Users
    # ../.usr.elly.nix # modularize this later

    # window-manager
    "${flakePath}/system-config/window-manager/_kde.nix"        # KDE

    # packages
    "${flakePath}/system-config/hosts/nire-durandal/durandal-packages.nix"      # system packages

    # firewall and ssh
    "${flakePath}/system-config/hosts/nire-durandal/firewall.nix"
    "${flakePath}/system-config/hosts/nire-durandal/ssh.nix"

    # nix generated
    "${flakePath}/system-config/hosts/nire-durandal/hardware-configuration.nix"
    "${flakePath}/system-config/hosts/nire-durandal/stateVersion.nix"

    # hardware
    "${flakePath}/system-config/hosts/nire-durandal/gpu.nix"

    # defaults and imports
    "${flakePath}/system-config/configuration.nix"

    # users
    "${flakePath}/system-config/users/elly/_sys.elly.nix"
    
    # fixes
    "${flakePath}/system-config/system-fixes/suspend/_b550m-gpp0-etc.nix"

    # tailscale
    "${flakePath}/system-config/services/__tailscale.nix"

    # impermanence
    # ____________________________________________________ 
    # |- /!!\ WARN: this will delete /root on boot /!!\ -|
    # ----------------------------------------------------
    "${flakePath}/system-config/impermanence/_WARN.impermanence.nix"  
  ];

  nix.nixPath = [ "nixpkgs=${nixpkgs}" ];                                       # make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
  
  # hostname
  networking.hostName = "nire-durandal";

  # TODO: turn into its own module
  musnix = {
    enable          = true;
    kernel.realtime = false;
    # das_watchdog.enable = true;                                               # starts the das watchdog which ensures realtime processes don't hang the machine
  };

  # TODO: stylix theme config also in it's own module
  # https://danth.github.io/stylix/configuration.htmloverride {argsOverride = {version = "6.6.27";};

  hardware.amdgpu.amdvlk.enable = false;    # disable amdvlk to use radv
  hardware.keyboard.zsa.enable = true;      # zsa keyboard package
  services.ratbagd.enable      = true;      # for piper logitech mouse ctl

  programs.steam = {
      enable = true;
      remotePlay.openFirewall      = true;  # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true;  # Open ports in the firewall for Source Dedicated Server
      gamescopeSession.enable      = true;  # third party gamescope compositor
    }; 
}

# ways of overriding kernel
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

  # musnix:
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
