{
    config,
    ...
}:

{
    import = [ 
        "./${config.networking.hostname}-hardware-configuration.nix" 
    ];
    
}
