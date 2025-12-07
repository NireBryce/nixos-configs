# description = "linux user-space NFS utilities";
{ pkgs, ... }:
let 
packageList = with pkgs; [
    nfs-utils
];
in
{
    environment.systemPackages = packageList;
}
