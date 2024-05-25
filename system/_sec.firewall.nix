{
  ...
}:

{
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
}
