{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # should fix steam/proton/wine issues with xdg-open https://github.com/NixOS/nixpkgs/issues/160923
            xdg.portal = {
                enable = true;
                xdgOpenUsePortal = true;

                # wlr.enable and xdg-desktop-portal-wlr are commented out, not removed --
                # found and fixed while looking into Sunshine's Wayland-portal capture path
                # (which turned out not to need portals at all; see sunshine.nix). Every
                # desktop host here runs KDE Plasma 6 / KWin (kde-base.nix), not a wlroots
                # compositor -- wlr.nix's screencast/portal backend is Sway/Hyprland-only
                # and was simply never going to match anything KWin registers itself under.
                # kde-base.nix already carried a comment expecting
                # `kdePackages.xdg-desktop-portal-kde` to live here and it never actually
                # did, so portal-mediated screen sharing (Discord, Zoom, OBS-via-portal) was
                # likely broken on every KDE host until this fix, independent of anything
                # about Sunshine.
                # wlr.enable = true;
                extraPortals = [
                    pkgs.xdg-desktop-portal
                    pkgs.xdg-desktop-portal-gtk
                    pkgs.kdePackages.xdg-desktop-portal-kde
                    # pkgs.xdg-desktop-portal-wlr
                ];
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-21 -- known upstream bug on every KDE host, since the wlr-to-kde switch above
#
# Once xdg-desktop-portal-kde is actually in the mix (rather than the never-matched wlr
# backend this file used to carry), every KDE login on durandal logs a burst of
# `Failed to register with host portal QDBusError("org.freedesktop.portal.Error.Failed",
# "Could not register app ID: Connection already associated with an application ID")`
# from kaccess, DiscoverNotifier, and xdg-desktop-portal-kde itself, at session start.
#
# This is KDE bug https://bugs.kde.org/show_bug.cgi?id=513595, open and unfixed through
# Plasma 6.7.4 -- the exact version this build runs -- not something wrong in this file.
# Per the bug's own comment #12, the failed app-ID registration leaves the portal
# daemon's internal KIO connection stuck "not inited" for the rest of the session, so
# this is not just a noisy log line: portal-mediated file opens, camera access, and
# "open containing folder" are plausibly broken every login until the next one. The
# documented workaround, confirmed live on durandal, is
# `systemctl --user restart xdg-desktop-portal.service plasma-xdg-desktop-portal-kde.service`,
# which fixes it for the rest of that session but has to be repeated after the next login.
#
# Before this file started actually loading xdg-desktop-portal-kde, nothing exercised
# this registration path on a KDE session, so the bug had nothing to trigger -- it isn't
# a regression from this change, just newly visible because of it.
