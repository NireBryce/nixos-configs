# uv - python version-, venv-, and packaging-management tool
{ den.bundles.hm.dev-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    uv
];
in
{   
    home.packages = packageList;
}
;}
