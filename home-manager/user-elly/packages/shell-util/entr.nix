{ ... }:
{
    # desc = "run commands when file changes";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        entr
    ];
    in
    {
        home.packages = packageList;
    };
}
