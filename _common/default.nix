{
  configs,
  pkgs,
  ...
}:
{ 
  imports = [
    # need to make this not bound to a particular partition scheme
    ./_bluetooth.nix
    ./_boot.nix
    ./_firewall.nix
    ./_impermanence.nix
    ./_sound.nix
    ./_ssh.nix
    ./_sys_packages.nix
    ./_users.nix
  ];

}
