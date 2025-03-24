{
    self,
    ...
}:

{
    imports = [ 
        "./${self.networking.hostName}-hardware-configuration.nix" 
    ];
    
}
