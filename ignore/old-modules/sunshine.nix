{
  pkgs,
  ...
}:
{
services.sunshine = {
  enable = true;
  autoStart = true;
  capSysAdmin = true;
  openFirewall = true;
};
  networking.firewall = {

    allowedTCPPorts = [ # ## Sunshine
      47984 
      47989 
      47990 
      48010 
    ];
    allowedUDPPortRanges = [
      { from = 47998; to = 48000; }
    ];
  };
}
