{ 
    inputs,
    den, 
   ... 
}:
{
# Consider renaming this module something like entrypoint

    imports = [ 
        (inputs.den.flakeModule)
        # (inputs.home-manager.flakeModules.default)

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
            includes = with den.ful; [ 
                nire.desktop-env._.kde
                nire.hardware._.amd
                nire.hardware._.amdgpu
                nire.impermanence._.impermanence # will delete your HD if you arent careful
                nire.nix
                nire.peripherals
                nire.shell-config
                nire.system
                nireHost.durandal
                nireUser.elly
                nirePackages.development
                nirePackages.editors
                nirePackages.linux-utils
                nirePackages.nix-utils
                nirePackages.gui-other
                nirePackages.shell-apps
                nirePackages.terminals
            ];
        };
    };
    
    # define user
    den.hosts.x86_64-linux = {
        nire-durandal = {
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
