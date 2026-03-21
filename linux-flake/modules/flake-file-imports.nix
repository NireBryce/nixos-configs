{ inputs, ... }:
{
    imports = [ inputs.flake-file.flakeModules.default ];
}
