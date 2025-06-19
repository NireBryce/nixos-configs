{ ... }:
{
    description = "nix antipattern linter";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        statix
    ];
    in
    {
        home.packages = packageList;
    };
}
