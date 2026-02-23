{
    ...
}:
{ den.aspects.srvc-kdeconnect.nixos = 
{ ... }: {
    # todo: shouldn't this be a service?
        programs.kdeconnect = {
            enable  = true;      # kde connect
        };
    };
}
