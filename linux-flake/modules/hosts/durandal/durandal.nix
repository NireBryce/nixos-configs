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
            <nire.development/all>
            <nire.editors/all>
            <nire.hardware/amd>
            <nire.impermanence/impermanence> # will delete your HD if you arent careful
            <nire.nix/all>
            <nire.packages/all>
            <nire.peripherals/all>
            <nire.shell-config/all>
            <nire.system/all>
            <nire.elly/all> 
        ];
        imports = [];
    };
}
