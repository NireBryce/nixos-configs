# Module file: named after this file; why it looks this way: wiki/module-files.md
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
