{ inputs, den, ... }:
{
    imports = [ 
        (inputs.den.flakeModule)
        (inputs.den.namespace "nire" false)
        (inputs.den.namespace "nireUser" false)
        (inputs.den.namespace "nireHost" false)
    ];

    # enables angle bracket syntax for imports shorthand
    # https://den.oeiuwq.com/guides/angle-brackets/
    # { __findFile, ... }: { includes = [ <nire.nix/all> ]; };
    _module.args.__findFile = den.lib.__findFile;




    
}
