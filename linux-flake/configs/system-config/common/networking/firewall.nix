{

    ...
}:

{
    # TODO: this module needs to be refactored for readability
    ## Firewall
    networking.firewall = { 
        enable = true;
      ## TCP
        allowedTCPPorts = [
            22                                          # ssh
        ];
        allowedTCPPortRanges = [  
            { from = 1714; to = 1764; }                 # kde-connect TCP
        ];
      ## UDP
        allowedUDPPorts = [                            
            5353                                        # mdns
            24470                                       # planetside2
            25410                                       # planetside2
            # config.services.tailscale.port              # todo: move to tailscale-autoconnect
        ];
        allowedUDPPortRanges = [
            { from =  1714; to =  1764; }               # kde-connect UDP
            { from = 20040; to = 20199; }               # planetside2
        ];
    
        trustedInterfaces = [ 
            "tailscale0"  # always allow traffic from your Tailscale network
            # TODO: move to tailscale-autoconnect
        ];
    };
}
