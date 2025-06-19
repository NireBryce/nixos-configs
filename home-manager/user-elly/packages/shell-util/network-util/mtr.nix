{ ... }:
{
    description = "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        mtr
    ];
    in
    {
        home.packages = packageList;
    };
}
