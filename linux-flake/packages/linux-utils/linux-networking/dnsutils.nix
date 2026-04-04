{ pkgs, ... }:
{
    # provides `dig` + `nslookup`
    home.packages = with pkgs; [
        dnsutils
    ];
}
