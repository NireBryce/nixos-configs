{ ... }:
{
    description = "file browser"; # TODO: better desc
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        yazi
    ];
    in
    {
        home.packages = packageList;
    };
}
