{ ... }:
{
    description = "nix packages from URLs"; # TODO: do I need this?
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nix-init
    ];
    in
    {
        home.packages = packageList;
    };
}
