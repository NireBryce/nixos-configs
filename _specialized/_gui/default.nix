{
  configs,
  pkgs,
  ...
}:
{ 
  imports = [
    ./_graphical-environment.nix
    ./_steam.nix
  ];
}
