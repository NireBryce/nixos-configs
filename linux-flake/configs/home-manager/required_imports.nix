{den, ...}:
let
imports = [
    den.aspects.hm.provides.aliases
    den.aspects.hm.provides.fonts
    den.aspects.hm.provides.git
    den.aspects.hm.provides.hm-settings
    den.aspects.hm.provides.home-config
    den.aspects.hm.provides.linux-tools 
    den.aspects.hm.provides.misc-dotfiles
    den.aspects.hm.provides.nix
    den.aspects.hm.provides.pkgs-cli
    den.aspects.hm.provides.pkgs-gui
    den.aspects.hm.provides.shell-config

];
in
{
    placeholder = imports;
}
