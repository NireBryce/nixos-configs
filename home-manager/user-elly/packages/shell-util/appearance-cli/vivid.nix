{ ... }:
{
    description = "LS_COLORS generator";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        vivid
    ];
    in
    {
        home.packages = packageList;
    };
}
