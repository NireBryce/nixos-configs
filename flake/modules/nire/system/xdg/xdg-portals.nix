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
