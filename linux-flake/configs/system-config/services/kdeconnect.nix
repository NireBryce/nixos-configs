{
    ...
}:
{
    flake.modules.nixos.core.kdeconnect = { pkgs, ... }: {
    # todo: shouldn't this be a service?
        programs.kdeconnect = {
            enable  = true;      # kde connect
        };
    };
}
