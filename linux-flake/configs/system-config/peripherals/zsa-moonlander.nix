{
    ...
}:
{
    flake.modules.nixos.hw.peripherals = { pkgs, ... }: {
        hardware.keyboard.zsa.enable        = true;         # zsa keyboard package
    };
}
