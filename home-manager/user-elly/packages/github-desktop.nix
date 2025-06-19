{ ... }:
{
    description = "github desktop";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        github-desktop
    ];
    in
    {
        home.packages = packageList;
    };
}
