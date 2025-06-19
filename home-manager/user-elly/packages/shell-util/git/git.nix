{ ... }:
{
    # desc = "git-scm";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        git
    ];
    in
    {
        home.packages = packageList;
    };
}
