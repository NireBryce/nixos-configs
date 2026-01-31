{
    ...
}:
{
    flake.modules.nixos.hw.peripherals = { pkgs, ... }: {
        services.ratbagd.enable             = true;         # for piper logitech mouse ctl
    };
}
