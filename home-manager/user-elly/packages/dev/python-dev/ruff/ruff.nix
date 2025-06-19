{ ... }:
{
    description = "python linter";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        ruff
    ];
    in
    {
        home.packages = packageList;
    };
}
