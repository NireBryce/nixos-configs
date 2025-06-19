{ ... }:
{
    description = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        ldns
    ];
    in
    {
        home.packages = packageList;
    };
}
