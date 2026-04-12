{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = {
        services.flatpak.enable = true;
        systemd.services.flatpak-repo = {
            wantedBy = [ "multi-user.target" ];
            path = [ pkgs.flatpak ];
            script = ''
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            '';
        };
    };
}
