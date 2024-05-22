# AMDGPU
{ pkgs, lib, config , ... }:
{
  options = {
    _amdgpu.enable = lib.mkEnableOption "Enables AMDGPU settings";
  };
  config = lib.mkIf config._amdgpu.enable {
    environment.systemPackages = with pkgs; [
      amf-headers
      mesa
    ];
    hardware.opengl.extraPackages = with pkgs; [
      libva-utils
    ];


  ### Everything below this is in nixos-hardware already ###
  
  #   boot.initrd.kernelModules = [ "amdgpu" ];
  #   environment.variables.AMD_VULKAN_ICD = "RADV"; # force RADV
  #   hardware.opengl = {
  #     # Radv - Open source vulkan driver from freedesktop
  #     driSupport      = true;
  #     driSupport32Bit = true;
    
  #     extraPackages = [
  #       # pkgs.stable.amdvlk
  #       pkgs.libva-utils # VA-API video acceleration
  #     ];

  #     # For 32 bit applications 
  #     extraPackages32 =  with pkgs; [
  #       # driversi686Linux.amdvlk
  #     ];

  #   };
    
  };
}
