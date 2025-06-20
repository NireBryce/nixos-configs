# desc = "provides `dig` + `nslookup`";
{ pkgs, ... }:
let packageList = with pkgs; [
    dnsutils
];
in
{
    home.packages = packageList;
}
