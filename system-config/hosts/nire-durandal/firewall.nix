{
  ...
}:

{
    services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    allowSFTP = false; # Don't set this if you need sftp
    # challengeResponseAuthentication = false; # folded into settings.KbdInteractiveAuthentication
    
    extraConfig = ''
      AllowTcpForwarding yes
      X11Forwarding no
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AuthenticationMethods publickey
    '';
  };
  
  networking.firewall = { 
    enable = true;
    allowedTCPPorts = [
    22                        # ssh
    ];
    allowedTCPPortRanges = [  
      { # kde-connect TCP
        from = 1714;
        to   = 1764;    
      }
    ];
    allowedUDPPorts = [                            
    ];
    allowedUDPPortRanges = [
      { ## kde-connect UDP 
        from = 1714;
        to   = 1764;
      }   
    ];
  };
}
