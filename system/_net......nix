{ ... }:

# networking metapackage
{
# wifi
  networking.networkmanager.enable = true;  # Needs to be 'true' for KDE networking
# firewall
  networking.firewall = { 
  enable = true;
  allowedTCPPorts = [
  22                        # ssh
  ];
  allowedTCPPortRanges = [  
    {                       # kde-connect TCP
      from = 1714;
      to   = 1764;    
    }
  ];
  allowedUDPPorts = [                            
  ];
  allowedUDPPortRanges = [
    {                       # kde-connect UDP 
      from = 1714;
      to   = 1764;
    }   
  ];
};
# Bluetooth
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.enable =  true;
  hardware.bluetooth.settings = {
    General = {
      FastConnectable = true;
      DiscoverableTimeout =  60;  # seconds
      PairableTimeout = 60;       # seconds
    };
  };
}

# services.blueman.enable = true;
