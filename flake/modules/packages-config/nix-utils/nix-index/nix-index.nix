# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ inputs, ... }:
{
    homeManager = {
        # package summary: nix-index -- finds the package providing a file; plus `,`
        imports = [
            inputs.nix-index-database.homeModules.default
        ];
        # these might be hm-only
        programs = {
            nix-index = {
                enable = true;
                enableFishIntegration = true;
            };
            nix-index-database.comma.enable = true;
        };
    };
}
