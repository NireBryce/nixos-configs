{ ... }:
{
    # desc = "back in my day we transfered our files uphill both ways";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        rsync
    ];
    in
    {
        home.packages = packageList;
    };
}
