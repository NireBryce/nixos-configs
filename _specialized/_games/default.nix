{lib, ...}:

{
  imports = [
    ./_steam.nix
  ];

  _steam.enable = lib.mkDefault false;
}
