# Plasma 6, and the parts of it that every host running a desktop wants.
#
# Split out of kde.nix -- now kde-desktop.nix -- so the handheld can have the
# desktop without the workstation's session handling. Before the split durandal
# imported the whole of kde.nix and tenacity imported none of it, taking
# plasma6 from jovian.nix alone. See the history block at the bottom for what
# that cost.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # Plasma 6 and the KDE bits shared by every desktop host

            services.xserver.enable = true; # TODO: I think this is still needed for xwayland

            # Enable the KDE Desktop Environment and set wayland.
            services.desktopManager.plasma6.enable = true;

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
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-10 — why this file exists, and what the split found
#
# `services.xserver.enable` was in kde.nix, which only durandal imported.
# Tenacity got `services.desktopManager.plasma6.enable` from jovian.nix instead,
# so it evaluated to a Plasma 6 session with xserver.enable = false: no
# XWayland, and no xorg-server, xrandr, xprop, xinput, xterm or
# xf86-input-libinput in systemPackages. Gamescope brings its own X server for
# the Steam session, so games were unaffected -- but an X11-only application
# launched from the *desktop* session had nothing to talk to.
#
# The pre-restructure tree had a separate configs/system-config/wm/kde/
# xwayland.nix, which suggests this was handled deliberately once and simply
# was not carried across the port. Nothing on this branch replaced it.
#
# Confirmed by evaluation before the split, not by reading:
#
#   services.xserver.enable   durandal true    tenacity false
#
# The other half of what tenacity was missing was this file's package list --
# konqueror, partitionmanager, kcharselect, polonium, krohnkite, libinput.
# spectacle and qttools it already had, since Plasma 6 pulls those in itself.
#
# Not a gap, though it looks like one: networkmanager.enable is mkDefault here,
# but both hosts get it as `true` from nire/system/networking/wifi.nix. Tenacity
# was never without networking.
