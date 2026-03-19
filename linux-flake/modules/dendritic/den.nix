# https://github.com/vic/vix/blob/unflake/modules/den.nix
{
    inputs,
    den,
    ...
}:
{
    imports = [
        inputs.den.flakeModule
        (inputs.den.namespace "nire" true)
        # TODO: check this
        # (inputs.den.namespace "elly" false)
    ];

    config._module.args.__findFile = den.lib.__findFile;
}
