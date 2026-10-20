# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    nixos = {
        hardware.enableAllFirmware = true;
        hardware.enableRedistributableFirmware = true;
        nixpkgs.config.allowUnfree = true; # enableAllFirmware depends on this
    };
}
