{ ... }:
{
    # desc = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        ethtool
    ];
    in
    {
        home.packages = packageList;
    };
}
