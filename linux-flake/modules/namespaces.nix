{ inputs, den, ... }:
{
    imports = [ 
        (inputs.den.namespace "nire" false)
    ];

    # enables angle bracket syntax for imports shorthand
    # https://den.oeiuwq.com/guides/angle-brackets/
    _module.args.__findFile = den.lib.__findFile;

}
