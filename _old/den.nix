# https://github.com/vic/vix/blob/unflake/modules/den.nix
{
    config,
    inputs,
    den,
    ...
}:
{
    imports = [
        inputs.den.flakeModule
        # TODO: check this
        (inputs.den.namespace "nire" true)
        (inputs.den.namespace "packages" true)
        (inputs.den.namespace "peripherals" true)
        (inputs.den.namespace "elly" false)
    ];

    config._module.args.__findFile = den.lib.__findFile;
}
