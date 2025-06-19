{ ... }:
{
    # desc = "provides `dig` + `nslookup`";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        dnsutils
    ];
    in
    {
        home.packages = packageList;
    };
}
