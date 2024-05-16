{lib, ...}:
{
  imports = [ 
    ./_gam.steam+.nix
  ];
_steam.enbable = lib.mkDefault true;
}
