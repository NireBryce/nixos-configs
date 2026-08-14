# PLACEHOLDER. nire-testbed (ThinkPad X270) has not been installed yet, so
# there is no real disk to read a layout from -- unlike hardware-configuration.nix
# on durandal and tenacity, which are nixos-generate-config output from actual
# installed machines. Everything below the fileSystems/swapDevices block is
# real; that block is not, and evaluating this host's toplevel today produces a
# config for a machine that does not exist.
#
# TODO before first boot: run `nixos-generate-config` on the real disk (from
# a NixOS installer image) and replace fileSystems/swapDevices/boot.initrd.*
# with its actual output. Keep everything else in this file -- the
# nixos-hardware import and the CPU/GPU pieces it brings are real regardless
# of how the disk ends up partitioned.
#
# No LUKS, no btrfs subvolumes, no impermanence: this host was deliberately
# NOT given the /root wipe durandal and tenacity have. See invariants.nix --
# it only enforces the rollback/hibernation/persistence group on hosts that
# actually have the restore-root unit, so a plain ext4 layout here is not
# fighting an invariant that assumes otherwise. If that decision changes
# before install, this file's fileSystems block should become LUKS + btrfs
# like durandal's, and `impermanence` needs adding to
# testbed-configuration.nix's import list.
#
# Wrapped as a flake-parts module for the same reason durandal/tenacity's
# hardware files are: a raw nixos-generate-config file under modules/ makes
# flake-parts resolve `modulesPath` through its own _module.args and dies with
# "infinite recursion encountered", naming modulesPath rather than this file.
#
# `inputs` is taken here (not in the inner lambda's own arg list) for the same
# reason amdcpu.nix does -- the inner NixOS module body closes over it from
# this outer scope to reach nixos-hardware, same as it closes over `lib`.
{ lib, inputs, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, lib, pkgs, modulesPath, ... }:
    {
      imports =
        [
          (modulesPath + "/installer/scan/not-detected.nix")

          # Lenovo ThinkPad X270-specific fixes from nixos-hardware: trackpoint,
          # TLP power management (common/pc/laptop), fstrim (common/pc/ssd),
          # Kaby Lake CPU microcode + integrated graphics (common/cpu/intel,
          # which pulls in common/gpu/intel), and i915.enable_psr=0 to work
          # around a known panel self-refresh freeze on this model.
          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x270
        ];

      # PLACEHOLDER -- see the file header. Generic single-disk ext4 layout,
      # not read from any real hardware. Replace entirely with
      # nixos-generate-config's actual output once this machine is installed.
      boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" =
        { device = "/dev/disk/by-label/TESTBED_ROOT"; # TODO: real UUID from install
          fsType = "ext4";
        };

      fileSystems."/boot" =
        { device = "/dev/disk/by-label/TESTBED_BOOT"; # TODO: real UUID from install
          fsType = "vfat";
          options = [ "fmask=0022" "dmask=0022" ];
        };

      swapDevices = [ ]; # TODO: real swap partition/file from install, if wanted

      networking.useDHCP = lib.mkDefault true;

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    }
;}
