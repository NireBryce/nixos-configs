{ ... }:
{
    # desc = "scan for 'dead' (uncalled) nix code";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        deadnix
    ];
    in
    {
        home.packages = packageList;
    };
}
