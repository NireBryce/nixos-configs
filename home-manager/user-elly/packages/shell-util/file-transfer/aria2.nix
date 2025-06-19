{ ... }:
{
    # desc = "cli download manager";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        aria2
    ];
    in
    {
        home.packages = packageList;
    };
}
