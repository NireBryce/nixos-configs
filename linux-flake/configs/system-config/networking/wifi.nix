{
    ...
}:
{
    flake.modules.nixos.networking.wifi = { pkgs, ... }: {
        networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
    };
}
