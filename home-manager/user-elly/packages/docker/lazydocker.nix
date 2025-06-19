{ ... }:
{
    description = "TUI docker interface";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        lazydocker
    ];
    in
    {
        home.packages = packageList;
    };
}
