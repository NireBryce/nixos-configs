{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.kitty ];

    flake.modules.homeManager.kitty =

{ pkgs, ... }:
{
    home.packages = with pkgs; [
        kitty-img
    ];
    
    programs.kitty = {
        enable  = true;
        extraConfig = ''
            clipboard_control write-clipboard write-primary read-clipboard-ask read-primary-ask
            kitty_mod ctrl+shift
        '';
        keybindings = {
            "kitty_mod+s" = "copy_to_clipboard";
            "cmd+c"       = "copy_or_interrupt";
            "kitty_mod+v" = "paste_from_clipboard";
            "cmd+v"       = "paste_from_clipboard";
        };
    };
}
;}
