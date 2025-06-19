{ ... }:
{
    # desc = "`find` alternative";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        fd
    ];
    in
    {
        home.packages = packageList;
    };
}
