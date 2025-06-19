{ ... }:
{
    # desc = "network tools https://software.es.net/iperf/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        iperf3
    ];
    in
    {
        home.packages = packageList;
    };
}
