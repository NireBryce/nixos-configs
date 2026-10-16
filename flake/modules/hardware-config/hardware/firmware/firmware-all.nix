# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    nixos = {
        hardware.enableAllFirmware = true;
        hardware.enableRedistributableFirmware = true;
        nixpkgs.config.allowUnfree = true; # enableAllFirmware depends on this
    };
}
