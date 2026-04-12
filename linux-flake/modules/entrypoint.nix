{ 
    __findFile,
    inputs,
    den, 
   ... 
}:
{
# Consider renaming this module something like entrypoint

    imports = [ 
        (inputs.den.flakeModule)

        # import namespaces here so they're loaded early
        (inputs.den.namespace "nire" false)
        (inputs.den.namespace "nireUser" false)
        (inputs.den.namespace "nireHost" false)
        (inputs.den.namespace "nirePackages" false)
    ];

    den.aspects = {
    # Aspects load before the namespaced modules do, so we need to use den.aspects here.
        nire-durandal = {
            description = "nire-durandal, workstation and gaming PC";
            includes = [ 
                den.provides.hostname
                <nire.desktop-env/kde>
                <nire.hardware/amdcpu>
                <nire.hardware/amdgpu>
                <nire.impermanence/impermanence> # will delete your HD if you arent careful
                <nire.nix>
                <nire.peripherals>
                <nire.shell-config>
                <nire.system>
                <nireHost.durandal>
                <nireUser.elly> 
                <nirePackages.development>
                <nirePackages.editors>
                <nirePackages.linux-utils>
                <nirePackages.nix-utils>
                <nirePackages.optional>
                <nirePackages.shell-apps>
                <nirePackages.terminal>
            ];
        };
    };

    # define user
    den.hosts.x86_64-linux = {
        nire-durandal = {
            home-manager.enable = true;
            users.elly = { 
                classes = [ "homeManager" ];
            };
        };
    };
    
    # enables angle bracket syntax for imports shorthand
    # https://den.oeiuwq.com/guides/angle-brackets/
    # everywhere it is must take __findFile, 
    # { __findFile, ... }: { includes = [ <nire.nix/all> ]; };
    _module.args.__findFile = den.lib.__findFile;
}
