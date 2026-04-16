{ inputs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = inputs.den.aspects.moduleStore._.${moduleName};
in
{
 
   
  ${aspectChain} = inputs.den.lib.perHost {
    nixos =
    { ... }:
    {
      # WARNING: IF YOU HAVE A SIMILAR LAYOUT TO MY LUKS SETUP, IMPORTING THIS WILL DELETE YOUR ROOT ON BOOT, so like, know what you're doing

      # filesystems
      fileSystems."/".options = [
        "compress=zstd"
        "noatime"
      ];
      fileSystems."/home".options = [ "compress=zstd" ];
      fileSystems."/nix".options = [
        "compress=zstd"
        "noatime"
      ];
      fileSystems."/persist".options = [
        "compress=zstd"
        "noatime"
      ];
      fileSystems."/persist".neededForBoot = true;
      fileSystems."/var/log".options = [
        "compress=zstd"
        "noatime"
      ];
      fileSystems."/var/log".neededForBoot = true;
      # fileSystems."/var/lib/sbctl".options        = [ "compress=zstd" "noatime" ];
      # fileSystems."/var/lib/sbctl".neededForBoot  = true;

      imports = [
        inputs.impermanence.nixosModule
      ];
      # impermanence
      environment.etc.machine-id.source = "/persist/etc/machine-id";

      environment.persistence."/persist" = {
        directories = [
          "/var/lib/bluetooth"
          "/var/lib/nixos"
          "/var/lib/systemd/coredump"
          "/etc/NetworkManager/system-connections"
          "/var/lib/flatpak"
        ];
        files = [
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
        ];
      };
      security.sudo.extraConfig = ''
        # impermanence-style wiping root results in sudo lectures after each reboot
        Defaults lecture = never
      '';

        # reset / at each boot
      boot.initrd = {
        enable = true;
        supportedFilesystems = [ "btrfs" ];

        systemd.services.restore-root = {
          description = "Rollback btrfs rootfs";
          wantedBy = [ "initrd.target" ];
          requires = [
            "dev-mapper-enc.device" # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
          ];
          after = [
            "dev-mapper-enc.device" # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html
            "systemd-cryptsetup@nire-durandal.service"
          ];#TODO: fix me to be general this is just to make it work for now
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          script = ''
            mkdir -p /mnt

            # We first mount the btrfs root to /mnt
            # so we can manipulate btrfs subvolumes.
            mount -o subvol=/ /dev/mapper/enc /mnt

            # While we're tempted to just delete /root and create
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
            # since I don't use it I'm not 100% sure.
            # Anyhow, deleting these subvolumes hasn't resulted
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

            # Once we're done rolling back to a blank snapshot,
            # we can unmount /mnt and continue on the boot process.
            umount /mnt
          '';
        };
      };
    };
  };
}
