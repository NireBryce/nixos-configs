{ ... }:
{
    # desc = "per-character in-line diff";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        riffdiff
    ];
    in
    {
        home.packages = packageList;
    };
}
