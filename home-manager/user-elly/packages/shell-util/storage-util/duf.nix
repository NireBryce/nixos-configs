{ ... }:
{
    description = "`df` alternative";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        duf
    ];
    in
    {
        home.packages = packageList;
    };
}
