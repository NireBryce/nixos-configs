{ ... }:
{
    # desc = "lspci";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        pciutils
    ];
    in
    {
        home.packages = packageList;
    };
}
