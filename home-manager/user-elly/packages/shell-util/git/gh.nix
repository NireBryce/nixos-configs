{ ... }:
{
    description = "github-cli";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        gh
    ];
    in
    {
        home.packages = packageList;
    };
}
