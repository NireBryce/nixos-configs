{ den, ... }: 
let
    # den.aspects.nire-durandal evaluates *.nixos
    # den.aspects.nire-durandal._.elly evaluates *.homeManager
    # TODO: there has to be a better way
    moduleList = with den.ful; [ 
        den.aspects.hmSettings._.hmConfig
        nire.desktop-env._.kde
        nire.hardware._.amdcpu
        nire.hardware._.amdgpu
        nire.nix
        nire.peripherals
        nire.shell-config
        nire.system
        nireUser.elly
        nirePackages.development
        nirePackages.editors
        nirePackages.linux-utils
        nirePackages.nix-utils
        nirePackages.gui-other
        nirePackages.shell-apps
        nirePackages.terminals 
    ];
in {
    den.aspects.nire-durandal = 
        {
        includes = [ 
            # since den.provides.hostname is fully qualified, it can be used under the `with`
            den.provides.hostname
            den.ful.nireHost.durandal
            den.ful.nire.impermanence._.impermanence # will delete your HD if you arent careful
        ] ++ [
            ({ class, ... }: builtins.trace "class for moduleList: ${class}" { includes = if class == "os" then moduleList else [];})
        ];

        _.elly = {
            # we need to do all the includes here so the homeManager sections can be processed under elly.
            # TODO: there has to be a better way
            includes = [
                den._.primary-user
            ] ++ [
                ({ class, ... }: builtins.trace "class: ${class}" { includes = if class == "homeManager" then moduleList else [];})
            ];
        };
        
    };
}

