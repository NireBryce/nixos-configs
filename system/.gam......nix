{lib, ...}:
{
  imports = [ 
    ./.gam.steam+.nix
  ];
_steam.enable = lib.mkDefault true;
}
