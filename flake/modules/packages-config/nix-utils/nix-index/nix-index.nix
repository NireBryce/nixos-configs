# Module file: named after this file; why it looks this way: wiki/module-files.md
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
