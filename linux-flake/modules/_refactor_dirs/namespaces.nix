{ inputs, den, ... }:
{
    imports = [ 
        (inputs.den.namespace "nire" false)
    ];

    # https://den.oeiuwq.com/guides/angle-brackets/
    _module.args.__findFile = den.lib.__findFile;

}
