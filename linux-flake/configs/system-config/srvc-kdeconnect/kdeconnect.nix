{
    ...
}:
{ den.aspects.nixos.provides.srvc-kdeconnect = 
{ ... }: {
    # todo: shouldn't this be a service?
        programs.kdeconnect = {
            enable  = true;      # kde connect
        };
    };
}
