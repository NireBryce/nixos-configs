{ ... }:
{
    # desc = "network scanner http://www.nmap.org/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nmap
    ];
    in
    {
        home.packages = packageList;
    };
}
