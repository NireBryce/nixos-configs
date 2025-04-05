{ 
  nixos-hardware,
  self,

  ... 
}: 
  
let 
    _relativePathRoot = self; # self is the flake's path
        _rPath = _relativePathRoot;
    _systemConfigFolder = "${_relativePathRoot}/system-config"; 
        _scPath = _systemConfigFolder;
    
    _submodulesList = [ 
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd
        "${_rPath}/___modules/linux-crisis-utilities.nix"
        "${_scPath}/hardware-configurations/nire-tenacity-hardware-configuration.nix"
        "${_scPath}/hardware-specific/zsa-moonlander.nix"
        "${_scPath}/hardware-specific/logitech-g600.nix"
        
        "${_scPath}/hardware-specific/amd/gpu.nix"
        "${_scPath}/hardware-specific/window-manager/gaming-handheld"
      
        "${_scPath}/common"
        "${_scPath}/gaming"
      # impermanence
      # ____________________________________________________ 
      # |- /!!\ WARN: this will delete /root on boot /!!\ -|
      # ----------------------------------------------------
        "${_scPath}/impermanence/_WARN.impermanence.nix"
    ];


in {
    imports = _submodulesList;
    
  
  ## hostname
    networking.hostName = "nire-tenacity";

  # don't change this without reading about it
    system.stateVersion = "25.05"; # Did you read the comment?
}

# TODO: figure out how to disable sticky keys when external keyboard plugged in.
