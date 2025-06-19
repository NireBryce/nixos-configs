{ ... }:
{
    # desc = "cli cheatsheets";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        cheat
    ];
    in
    {
        home.packages = packageList;
    };
}
