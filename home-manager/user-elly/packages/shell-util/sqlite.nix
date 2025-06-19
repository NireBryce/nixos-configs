{ ... }:
{
    # desc = "sqlite";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        sqlite
    ];
    in
    {
        home.packages = packageList;
    };
}
