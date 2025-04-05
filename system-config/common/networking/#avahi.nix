{
    ...
}:

{
  services.avahi = {
        enable          = true;
        nssmdns4        = true; # switch this to false if this doesn't work
        openFirewall    = true;
        publish = {
            enable          = true;
            userServices    = true;
            addresses       = true;
        };
    };
}
