# kitty's configuration. Installation, and the darwin/homebrew decision, are
# kitty.nix alongside this file.
#
# Platform-neutral on purpose: nothing here should ever need a stdenv check.
# The Homebrew kitty on nire-lysithea reads the same ~/.config/kitty/kitty.conf
# Home Manager generates from this, so both hosts get identical keybindings
# from one definition.
#
# Generates nothing on its own -- Home Manager wraps the whole programs.kitty
# config block in `mkIf cfg.enable`, and `enable` is set in kitty.nix. If this
# file's settings ever appear to do nothing, check that first.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            programs.kitty = {
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
        };
}
