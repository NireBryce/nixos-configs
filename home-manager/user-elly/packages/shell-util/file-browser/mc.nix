{ ... }:
{
    # desc = "midnight commander file browser";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        mc
    ];
    in
    {
        home.packages = packageList;
    };
}
