{
    config,
    ...
}:

{
    import = [ 
        "./${config.networking.hostName}-hardware-configuration.nix" 
    ];
    
}
