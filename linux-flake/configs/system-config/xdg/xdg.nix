{
    ...
}:
{
    flake.modules.nixos.core.xdg = { pkgs, ... }: {
        # should fix steam/proton/wine issues with xdg-open https://github.com/NixOS/nixpkgs/issues/160923 
        xdg.portal = { 
            enable           = true;
            xdgOpenUsePortal = true;
            wlr.enable       = true;
            extraPortals     = [
                pkgs.xdg-desktop-portal
                pkgs.xdg-desktop-portal-gtk
                pkgs.xdg-desktop-portal-wlr
            ];
        };
    };
}
