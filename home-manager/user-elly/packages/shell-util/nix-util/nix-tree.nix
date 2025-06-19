{ ... }:
{
    # desc = "view dependency graph";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nix-tree
    ];
    in
    {
        home.packages = packageList;
    };
}
