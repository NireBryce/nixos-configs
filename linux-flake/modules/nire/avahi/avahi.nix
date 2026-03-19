{ nire.avahi.nixos = 
{
    services.avahi = {
        nssmdns4 = true;
        enable = true;
        publish = {
            enable = true;
            userServices = true;
            domain = true;
        };
    };
};
}
