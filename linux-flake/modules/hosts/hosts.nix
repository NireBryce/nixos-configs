{ inputs, den, ... }:
{

    den.hosts.x86_64-linux = {
        nire-durandal = {
            home-manager.enable = true;
            users.elly = { 
                classes = [ "homeManager" ];
            };
        };
    };

    den.aspects.nire-durandal = {
        description = "nire-durandal, workstation and gaming PC";
        includes = [ 
            den.provides.hostname
            <nireHost.durandal/all>
            <nireUser.elly/all> 
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
        ];
        
        
        
    };
}
