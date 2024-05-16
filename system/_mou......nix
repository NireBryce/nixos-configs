{ lib, ...}:
{
  imports = [ 
    ./_mou.logitech+.nix
  ];
  _logitech.enable = lib.mkDefault true;
}
