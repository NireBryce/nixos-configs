# vscode - it is what it is
# other settings in system-config/dev/vscode-setup
# checkme: consider merging home-manager and system-config under same flake
# TODO: can you remove this?
{ den.aspects.hm.provides.pkgs-gui = 
{ pkgs, ... }:

{
    programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
    };
}
;}
