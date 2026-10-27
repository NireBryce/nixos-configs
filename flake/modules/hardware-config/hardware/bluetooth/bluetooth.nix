# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    nixos = {
        hardware.bluetooth = {
            powerOnBoot = true;
            enable = true;
            settings = {
                General = {
                FastConnectable = true;
                DiscoverableTimeout = 60; # seconds
                PairableTimeout = 60; # seconds
                };
            };
        };
    };
}
