let
  disk = "/dev/nvme0n1";
  swap_size = "16G";
in {
  disko.devices = {
    disk = {
      nvme0n1 = {
        type = "disk";
        device = disk ++ "p1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "fat32";
                mountpoint = "/boot";
              };
            };
            plainSwap = {
              size = swap_size;
              content = {
                type = "swap";
                resumeDevice = true; # resume from hiberation from this device
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/root" = {
                    mountOptions = [ "compress=zstd" "noatime" ];
                    mountpoint = "/";
                  };
                  # Subvolume name is the same as the mountpoint
                  "/home" = {
                    mountOptions = [ "compress=zstd" ];
                    mountpoint = "/home";
                  };
                  # Sub(sub)volume doesn't need a mountpoint as its parent is mounted
                    # "/home/user" = { };
                  # Parent is not mounted so the mountpoint must be set
                  "/nix" = {
                    mountOptions = [ "compress=zstd" "noatime" ];
                    mountpoint = "/nix";
                  };
                  "/persist" = {
                    mountOptions = [ "compress=zstd" "noatime" ];
                    mountpoint = "/persist";
                  };
                  "/log" = {
                    mountOptions = [ "compress=zstd" "noatime" ];
                    mountpoint = "/var/log";
                  };

                  # This subvolume will be created but not mounted
                    # "/test" = { };
                  
                  # # Subvolume for the swapfile
                  # "/swap" = {
                  #   mountpoint = "/.swapvol";
                  #   swap = {
                  #     swapfile.size = "20M";
                  #     swapfile2.size = "20M";
                  #     swapfile2.path = "rel-path";
                  #   };
                  # };
                };

              };
            };
          };
        };
      };
    };
  };
}
