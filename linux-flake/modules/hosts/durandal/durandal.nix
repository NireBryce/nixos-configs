{ inputs, ... }:
{
    nireHost.durandal = {
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        nixpkgs.hostPlatform = "x86_64-linux";
        networking.hostName = "nire-durandal"; # can maybe get rid of this with den.provides.hostname doing the work
        
        
        provides = {
            all = { lib, config }: { includes = lib.attrValues (removeAttrs config.provides [ "all" ]); };
            
            configuration = { imports = [ (inputs.import-tree ./_/configuration) ]; };
            
            hardware = { imports = [ (inputs.import-tree ./_/hardware) ]; };
        };   

    };
}


