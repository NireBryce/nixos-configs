{
    config,
    ...
}:


{
    cfg = config.networking;
    imports = [ 
        "./${cfg.networking.hostName}-hardware-configuration.nix" 
    ];
    
}
