# desc = "provides `dig` + `nslookup`";
{ flake.modules.homeManager.commonLinux.networkUtil.dnsutils =
{ pkgs, ... }:
let packageList = with pkgs; [
    dnsutils
];
in
{
    home.packages = packageList;
}
;}
