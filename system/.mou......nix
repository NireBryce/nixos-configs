{ lib, ...}:
{
  imports = [ 
    ./.mou.logitech+.nix
  ];
  _logitech.enable = lib.mkDefault true;
}
