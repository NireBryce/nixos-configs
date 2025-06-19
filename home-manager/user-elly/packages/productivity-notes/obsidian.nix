{ ... }:
{
    description = "Obsidian markdown PKM like org mode, https://obsidian.md/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let
        packageList = with pkgs; [
            obsidian
        ];
    in 
    {
        home.packages = packageList;
    };
}
