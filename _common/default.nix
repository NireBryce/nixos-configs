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
    ./_filesystem
    ./_networking
    ./_secrets
    ./_services
    ./_sound
    ./_ssh
    ./_packages.nix
    ./_users
  ];

}
