{ nixos-hardware, ... }: {
  imports = [
    nixos-hardware.nixosModules.common-cpu-amd
    nixos-hardware.nixosModules.common-gpu-amd
    # Users
    # ../.usr.elly.nix # modularize this later

    # nix generated
    ./hardware-configuration.nix
    ./stateVersion.nix
    

    # _def defaults
    ../../system/__def.common.nix

    # users
    ../../system/_usr.elly.nix
    
    # fixes
    ../../system/_bugfixes/_suspend/_b550m-gpp0-etc.nix
  ];
  # hostname
  networking.hostName = "nire-durandal";


  # TODO: turn into its own module
  musnix = {
    enable = true;
    kernel.realtime = false;
    # das_watchdog.enable = true; # starts the das watchdog which ensures realtime processes don't hang the machine
  };

  # TODO: stylix theme config also in it's own module
  # https://danth.github.io/stylix/configuration.htmloverride {argsOverride = {version = "6.6.27";};

  hardware.amdgpu.amdvlk = false;
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
