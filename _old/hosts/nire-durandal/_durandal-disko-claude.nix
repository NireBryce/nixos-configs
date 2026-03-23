# # this has not yet been checked for behavior and is not called
# { ... }:
# {
#   disko.devices = {
#     disk = {
#       main = {
#         type = "disk";
#         device = "/dev/nvme0n1";
#         content = {
#           type = "gpt";
#           partitions = {
#             # Partition 1: ESP/boot (~1GB FAT32)
#             ESP = {
#               size = "1G";
#               type = "EF00";
#               priority = 1;
#               content = {
#                 type = "filesystem";
#                 format = "vfat";
#                 mountpoint = "/boot";
#                 mountOptions = [ "umask=0077" ];
#               };
#             };

#             # Partition 2: Swap (20GB with label)
#             swap = {
#               size = "20G";
#               priority = 2;
#               content = {
#                 type = "swap";
#                 extraArgs = [ "-L" "Swap" ];
#                 resumeDevice = true;  # Enable hibernation support
#               };
#             };

#             # Partition 3: LUKS encrypted btrfs
#             luks = {
#               size = "100%";
#               priority = 3;
#               content = {
#                 type = "luks";
#                 name = "enc";
#                 # Remove passwordFile for interactive password entry during install
#                 # passwordFile = "/tmp/secret.key";
#                 settings = {
#                   allowDiscards = true;  # Essential for SSD TRIM support
#                   # Uncomment for key file-based unlock:
#                   # keyFile = "/tmp/secret.key";
#                 };
#                 extraOpenArgs = [
#                   "--allow-discards"
#                   "--perf-no_read_workqueue"
#                   "--perf-no_write_workqueue"
#                 ];
#                 content = {
#                   type = "btrfs";
#                   extraArgs = [ "-f" "-L" "nixos" ];
#                   subvolumes = {
#                     "/root" = {
#                       mountpoint = "/";
#                       mountOptions = [ "subvol=root" "compress=zstd" "noatime" ];
#                     };
#                     "/home" = {
#                       mountpoint = "/home";
#                       mountOptions = [ "subvol=home" "compress=zstd" ];
#                     };
#                     "/nix" = {
#                       mountpoint = "/nix";
#                       mountOptions = [ "subvol=nix" "compress=zstd" "noatime" ];
#                     };
#                     "/persist" = {
#                       mountpoint = "/persist";
#                       mountOptions = [ "subvol=persist" "compress=zstd" "noatime" ];
#                     };
#                     "/log" = {
#                       mountpoint = "/var/log";
#                       mountOptions = [ "subvol=log" "compress=zstd" "noatime" ];
#                     };
#                     # Blank subvolume for impermanence snapshot rollback
#                     "/root-blank" = {
#                       mountOptions = [ "subvol=root-blank" "compress=zstd" "noatime" ];
#                     };
#                   };
#                 };
#               };
#             };
#           };
#         };
#       };
#     };
#   };

#   # Required for impermanence - these subvolumes must be available early in boot
#   fileSystems."/persist".neededForBoot = true;
#   fileSystems."/var/log".neededForBoot = true;
# }
