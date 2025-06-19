{ ... }:
{
    description = "TUI git interface";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        lazygit
    ];
    in
    {
        home.packages = packageList;
    };
}
