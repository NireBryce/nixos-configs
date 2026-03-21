{ inputs, ... }:  
{

nire.nix-index.homeManager = 
{
    imports = [
        inputs.nix-index-database.homeModules.nix-index
    ];
    
    programs.nix-index.enable = true;
    programs.nix-index.enableFishIntegration = true;
    programs.nix-index.database.comma.enable = true;

}
;}

# make nix-index not use channels https://github.com/nix-community/nix-index/issues/167
