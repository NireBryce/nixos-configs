{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.nixos.${moduleName} = {
            # should fix steam/proton/wine issues with xdg-open https://github.com/NixOS/nixpkgs/issues/160923
            xdg.portal = {
                enable = true;
                xdgOpenUsePortal = true;
                wlr.enable = true;
                extraPortals = [
                    pkgs.xdg-desktop-portal
                    pkgs.xdg-desktop-portal-gtk
                    pkgs.xdg-desktop-portal-wlr
                ];
            };
        };
    };
}
