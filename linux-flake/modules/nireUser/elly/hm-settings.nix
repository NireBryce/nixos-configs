{
    den.aspects.home-manager = {
        provides.hmConfig = { lib, ... }: {
            homeManager = {
                home.stateVersion   = "22.11";
                home.username       = "elly";
                home.homeDirectory  = lib.mkDefault "/home/elly"; # Darwin is different
            };
        };
    };
}
