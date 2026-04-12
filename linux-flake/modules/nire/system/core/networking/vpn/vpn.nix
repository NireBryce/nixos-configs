{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        mullvad-vpn
        tailscale # TODO: move to module
      ];
    };
}
