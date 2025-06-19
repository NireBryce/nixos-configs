{ ... }:
{
    # desc = "show filetype";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        file
    ];
    in
    {
        home.packages = packageList;
    };
}
