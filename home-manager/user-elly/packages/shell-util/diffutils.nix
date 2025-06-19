{ ... }:
{
    # desc = "`diff` utils";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        diffutils
    ];
    in
    {
        home.packages = packageList;
    };
}
