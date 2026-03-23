{ self, inputs, ...}:
{ flake.modules.homeManager.nix-index = 
{
    imports = [
        inputs.nix-index-database.homeManagerModules.nix-index
    ];
    # these might be hm-only
    programs.nix-index.enable = true;
    programs.nix-index.enableFishIntegration = true;
    programs.nix-index.database.comma.enable = true;

}
;}
