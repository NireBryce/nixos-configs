# dirs-as-categories: the module is named after this file; its categories are the folders above it
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
