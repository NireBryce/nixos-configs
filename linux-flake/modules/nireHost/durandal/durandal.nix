{ den, ... }: {
    den.aspects.nire-durandal = {
        includes = with den.ful; [ 
            # since den.provides.hostname is fully qualified, it can be used under the `with`
            den.provides.hostname
            den.aspects.hmSettings._.hmConfig

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

        _.to-users = { };

        _.elly = {
            includes = [
                den._.primary-user
            ];
        };
        
    };
}

