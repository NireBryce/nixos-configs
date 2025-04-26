{ 
  nixos-hardware,
  self,
  pkgs,
  ... 
}: 

let 
    _relativePathRoot = self;   # self variable is the root location of the build tree
    _systemConfigFolder = "${_relativePathRoot}/system-config";

    _subModulesList = [
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd

        "${_relativePathRoot}/___modules/linux-crisis-utilities.nix"
        "${_systemConfigFolder}/hardware-configurations/nire-durandal-hardware-configuration.nix"
        "${_systemConfigFolder}/hardware-specific/zsa-moonlander.nix"
        "${_systemConfigFolder}/hardware-specific/logitech-g600.nix"

        "${_systemConfigFolder}/hardware-specific/amd/gpu.nix"

        "${_systemConfigFolder}/common"
        "${_systemConfigFolder}/gaming"

        "${_systemConfigFolder}/window-manager/_kde.nix"
        "${_systemConfigFolder}/users/_elly.nix"

        # impermanence
        # ____________________________________________________ 
        # |- /!!\ WARN: this will delete /root on boot /!!\ -|
        # ----------------------------------------------------
        "${_systemConfigFolder}/impermanence/_WARN.impermanence.nix"
    ]; 

in {
  # TODO: bring most of these back into the durandal configuration to better follow community conventions
  # TODO: start with linux-defaults next time
    imports = _subModulesList;
    

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

  ## nixos stateVersion for this system
  #   don't change this
  #   For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
    system.stateVersion = "23.11"; # Did you read the comment?

}
