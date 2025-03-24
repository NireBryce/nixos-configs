{
    config,
    ...
}:

{
    imports = [ 
        "./${config.networking.hostName}-hardware-configuration.nix" 
    ];
    
}
