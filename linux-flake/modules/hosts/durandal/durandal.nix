{

    den.hosts.x86_64-linux.nire-durandal = {
        users.elly = { };

    };

    nire.durandal = {
        description = "nire-durandal, workstation and gaming PC";
        
        provides = { imports, ... }: {
                configuration =  { imports = [ (imports.import-tree ./_/configuration) ]; };
                hardware = { imports = [ (imports.import-tree ./_/hardware) ]; };
            };
        
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
        nixpkgs.hostPlatform = "x86_64-linux";
        networking.hostName = "nire-durandal"; # can maybe get rid of this with den.provides.hostname doing the work
    };

    den.aspects.nire-durandal = { den, ... }: {
        includes = [ 
            den.provides.hostname
            <nire.desktop-env/kde>
            <nire.development>
            <nire.development>
            <nire.editors>
            <nire.hardware>
            <nire.impermanence>
            <nire.nix>
            <nire.packages>
            <nire.peripherals>
            <nire.shell-config>
            <nire.system>
            <nire.users> 
        ];
        imports = [];
    };
}
