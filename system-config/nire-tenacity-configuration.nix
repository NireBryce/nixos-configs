{ 
  nixos-hardware,
  self,
  ... 
}: 
  
let 
    _relativePathRoot = self; # self is the flake's path
    _systemConfigFolder = "${_relativePathRoot}/system-config"; 
    
    _submodulesList = [ 
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd
        "${_relativePathRoot}/___modules/linux-crisis-utilities.nix"
        "${_systemConfigFolder}/hardware-configurations/nire-tenacity-hardware-configuration.nix"
        "${_systemConfigFolder}/hardware-specific/zsa-moonlander.nix"
        "${_systemConfigFolder}/hardware-specific/logitech-g600.nix"
        
        "${_systemConfigFolder}/hardware-specific/amd/gpu.nix"
        "${_systemConfigFolder}/hardware-specific/window-manager/gaming-handheld"
      
        "${_systemConfigFolder}/common"
        "${_systemConfigFolder}/gaming"
      # impermanence
      # ____________________________________________________ 
      # |- /!!\ WARN: this will delete /root on boot /!!\ -|
      # ----------------------------------------------------
        "${_systemConfigFolder}/impermanence/_WARN.impermanence.nix"
    ];

in {
    imports = _submodulesList;
    networking.hostName = "nire-tenacity";

  # don't change this without reading about it
    system.stateVersion = "25.05"; # Did you read the comment?
}

# TODO: figure out how to disable sticky keys when external keyboard plugged in.
