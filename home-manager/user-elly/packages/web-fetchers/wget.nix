{ ... }:
{
    # desc = "its like curl but different https://www.gnu.org/software/wget/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        wget
    ];
    in
    {
        home.packages = packageList;
    };
}
