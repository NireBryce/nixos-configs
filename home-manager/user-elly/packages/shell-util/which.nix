{ ... }:
{
    description = "gnu which"; # TODO: better desc
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        which
    ];
    in
    {
        home.packages = packageList;
    };
}
