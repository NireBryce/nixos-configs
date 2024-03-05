{ pkgs, ... }:
{
  boot.initrd.kernelModules = [ "amdgpu" ];
  hardware.opengl.extraPackages = with pkgs; [
    amdvlk
  ];
  # For 32 bit applications 
  hardware.opengl.extraPackages32 = with pkgs; [
    driversi686Linux.amdvlk
  ];
  environment.systemPackages = with pkgs; [
    amf-headers
  ];
}
