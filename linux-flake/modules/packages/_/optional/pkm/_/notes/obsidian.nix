{
    description = "Obsidian - markdown PKM like org mode, https://obsidian.md/";
    
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            obsidian
        ];
    };
}
