{ nire.firmware-all.nixos = 
{
    hardware.enableAllFirmware = true;
    hardware.enableRedistributableFirmware = true;
    nixpkgs.config.allowUnfree = true; # enableAllFirmware depends on this
}
;}
