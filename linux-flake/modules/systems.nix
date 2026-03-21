{ den, lib, ... }:
{
    systems = lib.attrNames den.hosts;
    flake.lib.hostsBySystem = system: builtins.attrNames den.hosts.${system};
}

# https://github.com/vic/flake-file/blob/bb9fbe00ba6a1945fbdd6973c2585ab770f404b0/modules/dendritic/systems.nix
# { lib, ... }:
# {
#   systems = lib.mkDefault lib.systems.flakeExposed;
# }
