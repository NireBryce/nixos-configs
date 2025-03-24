{
    config,
    ...
}:

let cfg = config.networking;
in 
{
    imports = [ 
        "./${cfg.networking.hostName}-hardware-configuration.nix" 
    ];
    
}
