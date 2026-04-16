{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "kitty terminal emulator";
      home.packages = with pkgs; [
        kitty-img
      ];

      programs.kitty = {
        enable = true;
        extraConfig = ''
          clipboard_control write-clipboard write-primary read-clipboard-ask read-primary-ask
          kitty_mod ctrl+shift
        '';
        keybindings = {
          "kitty_mod+s" = "copy_to_clipboard";
          "cmd+c" = "copy_or_interrupt";
          "kitty_mod+v" = "paste_from_clipboard";
          "cmd+v" = "paste_from_clipboard";
        };
      };
    };
  };
}
