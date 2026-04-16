{ den, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost { 
    nixos =
    { pkgs, ... }:
    {
      services.xserver.enable = true; # TODO: I think this is still needed for xwayland

      # Enable the KDE Desktop Environment and set wayland.
      services.desktopManager.plasma6.enable = true;
      
      services.displayManager = {
        defaultSession = "plasma";
        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };

      networking = {
        networkmanager.enable = lib.mkDefault true; # Needs to be 'true' for KDE networking
      };

      # make GTK apps obey theme settings
      programs.dconf.enable = true;

      # fix electron fonts? https://github.com/electron/electron/issues/31797
      environment.systemPackages = with pkgs; [
        # kdePackages.xdg-desktop-portal-kde  # lives in xdg-portals
        kdePackages.spectacle # screenshot tool                          https://invent.kde.org/graphics/spectacle
        kdePackages.konqueror # one of the best `info` file pagers        https://invent.kde.org/network/konqueror
        kdePackages.qttools
        kdePackages.partitionmanager
        kdePackages.kcharselect # symbol picker, may need to be kdePackages.kcharselect
        polonium # tiling wm
        kdePackages.krohnkite # other tiling wm
        libinput # kde middle mouse scroll fix requires this
      ];

      environment.sessionVariables = {
        GTK_USE_PORTAL = 1;
      };
    };
  };
}
