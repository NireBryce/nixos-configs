{ ... }:
{
    description = "`nom`"; # TODO: better desc
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nix-output-monitor
    ];
    in
    {
        home.packages = packageList;
    };
}
