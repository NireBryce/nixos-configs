{ lib ,...}:
{ 
  
  imports = [
    # TODO: Disko
    ./_system-partitions.nix
    ./_impermanence.nix
    ./_delete-root.nix
  ];
  _impermanence.enable = lib.mkDefault false;
  _delete-root.enable = lib.mkDefault false;
  _system-partitions.enable = lib.mkDefault false;
}
