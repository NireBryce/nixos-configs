{
    config,
    ...
}:
let cfg = config;

in
{
    
    imports = [ 
        "./${cfg.system.networking.hostName}-hardware-configuration.nix" 
    ];
    
}
