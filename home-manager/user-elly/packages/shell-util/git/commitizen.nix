{ ... }:
{
    description = "commitizen"; # TODO: better description
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        commitizen
    ];
    in
    {
        home.packages = packageList;
    };
}
