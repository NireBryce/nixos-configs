{
    ...
}:
{
    flake.modules.nixos.hw.peripherals = { ... }: {
        services.ratbagd.enable             = true;         # for piper logitech mouse ctl
    };
}
