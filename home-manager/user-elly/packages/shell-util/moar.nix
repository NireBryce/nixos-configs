{ ... }:
{
    # desc = "better pager for some things https://github.com/walles/moar";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        moar
    ];
    in
    {
        home.packages = packageList;
    };
}
