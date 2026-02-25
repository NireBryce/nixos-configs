# Aspect: wm-kde — KDE Plasma desktop environment (NixOS side)
#
# This file follows the standard aspect pattern used throughout configs/:
#
#   outer module (flake-parts layer)
#   └── den.aspects.<name>.nixos = inner module (NixOS layer)
#
# The outer function `{ ... }:` is a flake-parts module. It discards its
# arguments (we don't need inputs here) and returns a single attribute set.
#
# den.aspects.wm-kde.nixos is the NixOS module for this aspect — a function
# that receives the standard NixOS arguments (lib, pkgs, config, …) plus
# any flake inputs forwarded via specialArgs in hosts/lib.nix.
#
# import-tree discovers this file automatically. There is no list to update;
# just dropping a file here is enough for its options to be merged into the
# final system config on the next rebuild.
#
# Reference: https://wiki.nixos.org/wiki/KDE
{
  ...
}:
{den.aspects.wm-kde.nixos =
{ lib, pkgs, ... }: 
{
    services.xserver.enable = true; # TODO: I think this is still needed for xwayland

    # Enable the KDE Desktop Environment and set wayland.
    services.desktopManager.plasma6.enable = true;
    services.displayManager = {
        defaultSession      = "plasma";        # TODO: remove this, it's meant to select for plasma6 but plasma 6 is the default now
        sddm = {
            enable          = true;
            wayland.enable  = true;
        };
    };

    networking = {
        networkmanager.enable = lib.mkDefault true;  # Needs to be 'true' for KDE networking
    };

    # make GTK apps obey theme settings
    programs.dconf.enable = true;

    # fix electron fonts? https://github.com/electron/electron/issues/31797
    environment.systemPackages = with pkgs; [
        kdePackages.xdg-desktop-portal-kde
        kdePackages.spectacle         # screenshot tool                          https://invent.kde.org/graphics/spectacle
        kdePackages.konqueror         # one of the best `info` file pagers        https://invent.kde.org/network/konqueror
        kdePackages.qttools
        kdePackages.partitionmanager
        kdePackages.kcharselect       # symbol picker, may need to be kdePackages.kcharselect
        polonium # tiling wm
        kdePackages.krohnkite # other tiling wm
    ];

    environment.sessionVariables = {
        GTK_USE_PORTAL = 1;  # TODO: what does this do
    };

}
;}
