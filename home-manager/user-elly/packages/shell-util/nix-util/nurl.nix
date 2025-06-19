{ ... }:
{
    description = "make nix fetcher calls from repository URLs";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nurl
    ];
    in
    {
        home.packages = packageList;
    };
}
