{
    ...
}:
{
    flake.modules.nixos.core.kdeconnect = { ... }: {
    # todo: shouldn't this be a service?
        programs.kdeconnect = {
            enable  = true;      # kde connect
        };
    };
}
