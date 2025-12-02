# TODO: fix comma
# description = "`,` - `nix-shell -p` style run commands without installing to env";
{ pkgs, ... }:
let 
# packageList = with pkgs; [
#     comma
# ];
in
{
    programs.nix-index-database.comma.enable = true;
    # home.packages = packageList;
}
