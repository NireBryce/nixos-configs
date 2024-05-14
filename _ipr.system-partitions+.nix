{ lib, config, ... }:

{
  # TODO: remove belt and suspenders once you verify it works by just setting `config = lib.mkif config._impermanence.enable`
options = {
  _system-partitions.enable = lib.mkEnableOption "Enables system partitions";
};
config = lib.mkIf config._system-partitions.enable {
    # filesystems
    fileSystems."/".options = [ "compress=zstd" "noatime" ];
    fileSystems."/home".options = [ "compess=zstd" ];
    fileSystems."/nix".options = [ "compress=zstd" "noatime" ];
    fileSystems."/persist".options = [ "compress=zstd" "noatime" ];
    fileSystems."/persist".neededForBoot = true;
    fileSystems."/var/log".options = [ "compress=zstd" "noatime" ];
    fileSystems."/var/log".neededForBoot = true;
  };
}
