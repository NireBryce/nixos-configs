{ lib, ... }: { 
    homeManager = {
        users.elly = {
            home.stateVersion   = "22.11";
            home.username       = "elly";
            home.homeDirectory  = lib.mkDefault "/home/elly";
        };
    };
}
