{
  pkgs,
  lib,
  ...
}: {
  imports = [
    # Users
    # ../_usr.elly.nix # modularize this later

    # nix generated
    ./hardware-configuration.nix
    ./stateVersion.nix

    # _def defaults
    ../__def.common.nix

    # fixes
    ../_bugfixes/_suspend/_b550m-gpp0-etc.nix
  ];
  # hostname
  networking.hostName = "nire-durandal";
  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_6.override {argsOverride = {version = "6.6.27";};});
  # boot.kernelPackages = lib.mkForce pkgs.linuxKernel.kernels.linux_6_6;

  _gui.enable = true;
  _amdgpu.enable = true;
  _steam.enable = true;

  _bluetooth.enable = true;
  _pipewire.enable = true;
  _pipewire-bt.enable = true;
  _wifi.enable = true;
  _firewall.enable = true;
  _zsa.enable = true;
  _logitech.enable = true;

  _impermanence.enable = true;
  _delete-root.enable = true;
  _system-partitions.enable = true;
}
