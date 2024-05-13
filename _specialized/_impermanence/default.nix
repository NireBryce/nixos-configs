{ lib, config, ...}:
{ 
  options = {
    _impermanence.enable = lib.mkEnableOption "Enables impermanence";
  };
  config = lib.mkIf config._impermanence.enable {
    imports = [
      # TODO: Disko
      ./_system-partitions.nix
      ./_impermanence.nix
      ./_delete-root.nix
    ];
  };
}
