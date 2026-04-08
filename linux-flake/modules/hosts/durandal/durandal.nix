{ inputs, ... }:
{
    nireHost.durandal = {
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        nixpkgs.hostPlatform = "x86_64-linux";
        networking.hostName = "nire-durandal"; # can maybe get rid of this with den.provides.hostname doing the work
        
        includes = with nireHost.durandal.provides; [
            <nireHost.durandal/configuration>
            <nireHost.durandal/hardware>
        ];
        provides = { inputs, ... }: {
                # all = { imports = [ (inputs.import-tree ./_) ]; };
                configuration =  { imports = [ (inputs.import-tree ./_/configuration) ]; };
                hardware = { imports = [ (inputs.import-tree ./_/hardware) ]; };
            };   

    };
}


