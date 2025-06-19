{ ... }:
{
    description = "bash linter";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        shellcheck
    ];
    in
    {
        home.packages = packageList;
    };
}
