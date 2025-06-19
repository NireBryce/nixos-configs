{ ... }:
{
    description = "`du` alternative";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        du-dust
    ];
    in
    {
        home.packages = packageList;
    };
}
