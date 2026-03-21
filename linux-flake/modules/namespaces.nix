{ inputs, ...}:
{
    _module.args.__findFile = inputs.den.lib.__findFile;
    imports = [ # can we put these with where they're invoked somehow?
        (inputs.den.namespace "nire" true)
        (inputs.den.namespace "packages" true)
        (inputs.den.namespace "peripherals" true)
        (inputs.den.namespace "hosts" true)
        (inputs.den.namespace "workstation" true)
        
        (inputs.den.namespace "users" true)
        (inputs.den.namespace "elly" true)


    ];
}

# https://github.com/vic/vix/blob/den/modules/namespace.nix
# { inputs, den, ... }:
# {
#   _module.args.__findFile = den.lib.__findFile;
#   imports = [
#     (inputs.den.namespace "vix" true)
#     (inputs.den.namespace "vic" false)
#     (inputs.den.namespace "my" false)
#   ];
# }
