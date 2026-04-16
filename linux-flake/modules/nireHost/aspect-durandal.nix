{ den, ... }: 
let
    # den.aspects.nire-durandal evaluates *.nixos
    # den.aspects.nire-durandal._.elly evaluates *.homeManager
    # TODO: there has to be a better way
    moduleList = with den.aspects;[ 
        boot
        desktop-env._.kde
        # moduleStore._.kde
        hardware._.amdcpu
        hardware._.amdgpu
        nix
        peripherals
        shell-config
        system
        elly
        hm-settings

        development
        editors
        linux-utils
        nix-utils
        gui-other
        shell-apps
        terminals 
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

