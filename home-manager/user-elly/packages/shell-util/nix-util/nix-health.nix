{ ... }:
{
    description = "check nix issues";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nix-health
    ];
    in
    {
        home.packages = packageList;
    };
}
