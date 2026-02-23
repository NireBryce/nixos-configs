{den, ...}:
let
imports = [
    den.aspects.aliases.homeManager
    den.aspects.fonts.homeManager
    den.aspects.git.homeManager
    den.aspects.hm-settings.homeManager
    den.aspects.home-config.homeManager
    den.aspects.linux-tools.homeManager 
    den.aspects.misc-dotfiles.homeManager
    den.aspects.nix.homeManager
    den.aspects.pkgs-cli.homeManager
    den.aspects.pkgs-gui.homeManager
    den.aspects.shell-config.homeManager

];
in
{
    placeholder = imports;
}
