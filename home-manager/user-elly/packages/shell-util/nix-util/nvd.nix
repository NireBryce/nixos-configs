{ ... }:
{
    # desc = "nix package version diff";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nvd
    ];
    in
    {
        home.packages = packageList;
    };
}
