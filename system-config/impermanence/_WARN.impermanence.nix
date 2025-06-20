{ lib, inputs, ...}:

# impermanence metapackage
# THIS WILL DELETE YOUR ROOT ON BOOT, so like, know what you're doing

# consider https://www.reddit.com/r/NixOS/comments/1ad0m5n/impermanence_disko_setup/
{
  imports = [
    inputs.impermanence.nixosModule
  ];
# TODO: Disko configs

# filesystems
  fileSystems."/".options = [ "compress=zstd" "noatime" ];
  fileSystems."/home".options = [ "compress=zstd" ];
  fileSystems."/nix".options = [ "compress=zstd" "noatime" ];
  fileSystems."/persist".options = [ "compress=zstd" "noatime" ];
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".options = [ "compress=zstd" "noatime" ];
  fileSystems."/var/log".neededForBoot = true;

# impermanence
  environment.etc.machine-id.source = "/persist/etc/machine-id";  

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
        # "/etc/nixos" # no longer needed with the flake.
        # { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
      
    ];
    files = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
        # { file = "/var/keys/secret_file"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
        # "/etc/machine-id"
    ];
  };
  security.sudo.extraConfig = ''
    # impermanence-style wiping root results in sudo lectures after each reboot
    Defaults lecture = never
  '';

# delete root at boot

# postResumeCommands comes from https://github.com/NixOS/nixpkgs/pull/240651
  boot.initrd.postResumeCommands = lib.mkAfter ''
      mkdir -p /mnt
    # We first mount the btrfs root to /mnt
    # so we can manipulate btrfs subvolumes.
      mount -o subvol=/ /dev/mapper/enc /mnt

    # While we\'re tempted to just delete /root and create
    # a new snapshot from /root-blank, /root is already
    # populated at this point with a number of subvolumes,
    # which makes `btrfs subvolume delete` fail.
    # So, we remove them first.
    #
    # /root contains subvolumes:
    # - /root/var/lib/portables
    # - /root/var/lib/machines
    #
    # I suspect these are related to systemd-nspawn, but
    # since I don\'t use it I\'m not 100% sure.
    # Anyhow, deleting these subvolumes hasn\'t resulted
    # in any issues so far, except for fairly
    # benign-looking errors from systemd-tmpfiles.
      btrfs subvolume list -o /mnt/root |
      cut -f9 -d' ' |
      while read subvolume; do
        echo "deleting /$subvolume subvolume..."
        btrfs subvolume delete "/mnt/$subvolume"
      done &&
      echo "deleting /root subvolume..." &&
      btrfs subvolume delete /mnt/root

      echo "restoring blank /root subvolume..."
      btrfs subvolume snapshot /mnt/root-blank /mnt/root

    # Once we\'re done rolling back to a blank snapshot,
    # we can unmount /mnt and continue on the boot process.
        umount /mnt
  '';
}
