# AMDGPU
{ pkgs, lib, config , ... }:
{
  options = {
    _amdgpu.enable = lib.mkEnableOption "Enables AMDGPU settings";
  };
  config = lib.mkIf config._amdgpu.enable {
    boot.initrd.kernelModules = [ "amdgpu" ];
    environment.variables.AMD_VULKAN_ICD = "RADV"; # force RADV
    hardware.opengl = {
      # Radv - Open source vulkan driver from freedesktop
      driSupport      = true;
      driSupport32Bit = true;
    
      extraPackages = with pkgs; [
        amdvlk
        libva-utils # VA-API video acceleration
      ];

      # For 32 bit applications 
      extraPackages32 =  with pkgs; [
        driversi686Linux.amdvlk
      ];

    };
    
    environment.systemPackages = with pkgs; [
      amf-headers
      mesa
      
    ];
  };
}
