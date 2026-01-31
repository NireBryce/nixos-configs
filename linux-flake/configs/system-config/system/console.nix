{
    ...
}:
{
    flake.modules.nixos.core.console = { ... }: {
        console = {
            keyMap  = "us";
            font    = "Lat2-Terminus16";
        };
    };
}
