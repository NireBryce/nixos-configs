{ ... }:
{
    description = "diff nix code";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nix-diff
    ];
    in
    {
        home.packages = packageList;
    };
}
