{ den, flake, ...}:
# TODO: this is wrong and will need to be modified for flake-parts
    let
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
        development
        editors
        linux-utils
        nix-utils
        gui-other
        shell-apps
        terminals 
    ];
in {
    flake.nixosConfigurations.nire-durandal = {
        includes = [ 
            # since den.provides.hostname is fully qualified, it can be used under the `with`
            den.provides.hostname
            den.aspects.durandal
        ] ++ moduleList;
    };
    flake.homeConfigurations.elly-nire-durandal = {
        # we need to do all the includes here so the homeManager sections can be processed under elly.
        # TODO: there has to be a better way
        includes = [
            flake.modules.elly
        ] ++ moduleList;
    };
}

