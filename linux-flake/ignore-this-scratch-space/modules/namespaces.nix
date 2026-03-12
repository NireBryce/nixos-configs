{ inputs, den, ...}:
{
    _module.args.__findFile = den.lib.__findFile;
    imports = [ # can we put these with where they're invoked somehow?
        (inputs.den.namespace "nire" true)
        (inputs.den.namespace "durandal" true)
        (inputs.den.namespace "cpu" true)
        (inputs.den.namespace "gpu" true)
        (inputs.den.namespace "elly" false)
        (inputs.den.namespace "my" false)
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
