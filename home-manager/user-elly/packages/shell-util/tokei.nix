{ ... }:
{
    description = "count lines of code";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        tokei
    ];
    in
    {
        home.packages = packageList;
    };
}
