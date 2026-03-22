{ self, inputs, ...}:
{ flake.nixosModules.firmware-all =
{
    hardware.enableAllFirmware = true;
    hardware.enableRedistributableFirmware = true;
    nixpkgs.config.allowUnfree = true; # enableAllFirmware depends on this
}
;}
