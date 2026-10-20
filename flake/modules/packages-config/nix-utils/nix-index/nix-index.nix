# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ inputs, ... }:
{
    homeManager = {
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
