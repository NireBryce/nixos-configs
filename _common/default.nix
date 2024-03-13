{
  configs,
  pkgs,
  ...
}:
{ 
  imports = [
    # need to make this not bound to a particular partition scheme
    ./_bluetooth
    ./_boot
    ./_networking
    ./_filesystem
    ./_sound.nix
    ./_ssh.nix
    ./_sys_packages.nix
    ./_users.nix
  ];

}
