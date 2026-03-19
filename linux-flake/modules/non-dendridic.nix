# # https://github.com/vic/vix/blob/den/modules/non-dendritic.nix
# { den, ... }:
# {
#   den.default.includes = [
#     (den._.import-tree._.host ../nix/hosts)
#   ];
# }

{ den, ... }:
{
    den.default.includes = [
        # TODO: REPLACEME
        # (den._.import-tree._.host ../nix/hosts)
    ];
}
