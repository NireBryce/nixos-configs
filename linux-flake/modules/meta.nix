{ inputs, den, ... }:
{
    imports = [ 
        (inputs.den.flakeModules.dendritic)
        (inputs.den.namespace "nire" false)
        (inputs.den.namespace "nireUser" false)
        (inputs.den.namespace "nireHost" false)
        

    ];

    # enables angle bracket syntax for imports shorthand
    # https://den.oeiuwq.com/guides/angle-brackets/
    _module.args.__findFile = den.lib.__findFile;



    
}
