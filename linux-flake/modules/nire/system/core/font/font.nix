{ den,lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perHost {
    nixos =
    { pkgs, ... }:
    {
      console = {
        keyMap = "us";
        font = "Lat2-Terminus16";
      };
      fonts = {
        packages = with pkgs; [
          nerd-fonts.jetbrains-mono
          nerd-fonts.iosevka
          nerd-fonts.fira-code
        ];
        fontconfig = {
          enable = true;
          ## fix firefox and GTK emoji rendering issues https://discourse.nixos.org/t/firefox-doesnt-render-noto-color-emojis/51202/2
          useEmbeddedBitmaps = true;
        };
      };
    };
  };
  ${aspectChain} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # font packages that are per-user through home-manager
      # duplicated in system fonts, is this for non-nix hosts? consider moving to there
      home.packages = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.iosevka
        nerd-fonts.jetbrains-mono
      ];
    };
  };
}
