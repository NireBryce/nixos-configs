{
    ...
}:
{
    flake.modules.nixos.hw.peripherals = { ... }: {
        hardware.keyboard.zsa.enable        = true;         # zsa keyboard package
    };
}
