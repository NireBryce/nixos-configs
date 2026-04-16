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

    den.default = { lib, ... }: {
        includes = [ den.provides.define-user ];
        homeManager.home.stateVersion = lib.mkDefault "22.11";
        nixos.system.stateVersion = "23.11";
    };
    den.ctx.user.includes = [
        den._.mutual-provider # allows the host to define user aspect stuff through providers
    ];

    
    # enables angle bracket syntax for imports shorthand
    # https://den.oeiuwq.com/guides/angle-brackets/
    # everywhere it is must take __findFile, 
    # { __findFile, ... }: { includes = [ <nire.nix/all> ]; };
    _module.args.__findFile = den.lib.__findFile;
}
