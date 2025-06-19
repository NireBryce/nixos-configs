{ ... }:
{
    # desc = "fselect - I don't remember what this does"; # TODO: better desc
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        fselect
    ];
    in
    {
        home.packages = packageList;
    };
}
