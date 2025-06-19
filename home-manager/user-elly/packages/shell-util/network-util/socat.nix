{ ... }:
{
    # desc = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        socat
    ];
    in
    {
        home.packages = packageList;
    };
}
