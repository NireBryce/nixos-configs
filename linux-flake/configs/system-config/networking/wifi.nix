{
    ...
}:
{
    flake.modules.nixos.networking.wifi = { ... }: {
        networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
    };
}
