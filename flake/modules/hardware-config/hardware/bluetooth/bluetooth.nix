# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
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
