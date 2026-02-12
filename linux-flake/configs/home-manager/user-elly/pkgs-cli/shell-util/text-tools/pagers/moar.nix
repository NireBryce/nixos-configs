# desc = "better pager for some things https://github.com/walles/moor";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    moor # moar renamed to moor https://github.com/walles/moor/pull/305
];
in
{
    home.packages = packageList;
}
;}
