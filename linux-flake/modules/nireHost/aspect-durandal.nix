{ den, ... }: 
let
    # den.aspects.nire-durandal evaluates *.nixos
    # den.aspects.nire-durandal._.elly evaluates *.homeManager
    # TODO: there has to be a better way
    moduleList = with den.ful; [ 
        den.aspects.boot
        # den.aspects.desktop-env._.kde
        den.aspects.moduleStore._.kde
        den.aspects.hardware._.amdcpu
        den.aspects.hardware._.amdgpu
        den.aspects.nix
        den.aspects.peripherals
        nire.shell-config
        den.aspects.system
        den.aspects.elly
        den.aspects.hmSettings._.hmConfig

        nirePackages.development
        nirePackages.editors
        nirePackages.linux-utils
        nirePackages.nix-utils
        nirePackages.gui-other
        nirePackages.shell-apps
        nirePackages.terminals 
    ];
in {
    den.aspects.nire-durandal = {
        includes = [ 
            # since den.provides.hostname is fully qualified, it can be used under the `with`
            den.provides.hostname
            den.aspects.durandal
        ] ++ [
            ({ class, ... }: builtins.trace "class for moduleList: ${class}" { includes = if class == "os" then moduleList else [];})
        ];
    };
    den.aspects.elly._.nire-durandal = {
            # we need to do all the includes here so the homeManager sections can be processed under elly.
            # TODO: there has to be a better way
            includes = [
                den._.primary-user
                
            ] ++ [
                ({ class, ... }: builtins.trace "class: ${class}" { includes = if class == "homeManager" then moduleList else [];})
            ];
    };
}

