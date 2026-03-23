{ self, inputs, ...}:
{ flake.modules.nixos.firmware-all =
{
    hardware.enableAllFirmware = true;
    hardware.enableRedistributableFirmware = true;
    nixpkgs.config.allowUnfree = true; # enableAllFirmware depends on this
}
;}
