{ den, ... }: 
let
    # den.aspects.nire-durandal evaluates *.nixos
    # den.aspects.nire-durandal._.elly evaluates *.homeManager
    # TODO: there has to be a better way
    moduleList = with den.ful; [ 
        den.aspects.hmSettings._.hmConfig
        den.aspects.desktop-env._.kde
        den.aspects.hardware._.amdcpu
        den.aspects.hardware._.amdgpu
        den.aspects.nix
        den.aspects.peripherals
        nire.shell-config
        nire.system
        den.aspects.elly
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
            den.aspects.durandal
            den.aspects.boot
            den.ful.nire.system._.core
            den.ful.nire.system._.gaming
            den.ful.nire.system._.
            { 
                nix.extraOptions = "experimental-features = nix-command flakes";
                nix.settings = {
                    trusted-users = [ "root" ];
                    experimental-features = [
                        # duplicated in extraOptions?
                        "nix-command"
                        "flakes"
                    ];
                }; 
            }
        ] ++ [
            ({ class, ... }: builtins.trace "class for moduleList: ${class}" { includes = if class == "os" then moduleList else [];})
        ];

        _.elly = {
            # we need to do all the includes here so the homeManager sections can be processed under elly.
            # TODO: there has to be a better way
            includes = [
                den._.primary-user
                { 
                    nix.extraOptions = "experimental-features = nix-command flakes";
                    nix.settings = {
                        trusted-users = [ "root" ];
                        experimental-features = [
                            # duplicated in extraOptions?
                            "nix-command"
                            "flakes"
                        ];
                    }; 
                }
            ] ++ [
                ({ class, ... }: builtins.trace "class: ${class}" { includes = if class == "homeManager" then moduleList else [];})
            ];
        };
        
    };
}

