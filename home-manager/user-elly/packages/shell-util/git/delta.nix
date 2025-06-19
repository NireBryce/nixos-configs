{ ... }:
{
    description = "git diff viewer";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        delta
    ];
    in
    {
        home.packages = packageList;
    };
}
