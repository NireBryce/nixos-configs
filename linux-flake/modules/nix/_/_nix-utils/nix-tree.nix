{
    description = "view dependency graph";
    homeManager = 
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            nix-tree
        ];
    };
}
