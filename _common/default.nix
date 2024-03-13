{
  configs,
  pkgs,
  ...
}:
{ 
  imports = [
    # need to make this not bound to a particular partition scheme
    ./_boot
    ./_filesystem
    ./_networking
    ./_packages
    ./_secrets
    ./_services
    ./_ssh
    ./_users
  ];

}
