{
    den.aspects.hmSettings = {
        provides.hmConfig = { lib, ... }: {
            homeManager = {
                # home.stateVersion   = lib.mkDefault "22.11";
                home.username       = lib.mkDefault "elly";
                home.homeDirectory  = lib.mkDefault "/home/elly"; # Darwin is different
            };
        };
    };
}
