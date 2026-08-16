# nire-testbed (ThinkPad X270). fileSystems/boot.initrd.* below are real,
# sourced from `nixos-generate-config` run against the actual partitioned
# disk -- see the history note at the bottom for what stood here before this
# and why. Everything else in this file (the nixos-hardware import, the
# CPU/GPU pieces it brings) was already real regardless of how the disk ended
# up partitioned.
#
# No LUKS, no btrfs subvolumes, no impermanence: this host was deliberately
# NOT given the /root wipe durandal and tenacity have. See invariants.nix --
# it only enforces the rollback/hibernation/persistence group on hosts that
# actually have the restore-root unit, so a plain ext4 layout here is not
# fighting an invariant that assumes otherwise.
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

      # rtsx_pci_sdmmc is the X270's SD card reader -- present in the real
      # scan, wasn't guessable from the placeholder. usbhid dropped: not
      # detected against the real disk/controller, unlike the placeholder's
      # generic guess.
      boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" =
        { device = "/dev/disk/by-uuid/298d1ce7-3fb9-4918-b77c-21d419ccf62a";
          fsType = "ext4";
        };

      fileSystems."/boot" =
        { device = "/dev/disk/by-uuid/DED7-8FEF";
          fsType = "vfat";
          options = [ "fmask=0022" "dmask=0022" ];
        };

      # No disk-backed swap -- swap on this host is zram only, see
      # swap-testbed.nix right next to this file. Not this file's concern:
      # zram is a separate /dev/zramN device, not a swapDevices entry.
      swapDevices = [ ];

      networking.useDHCP = lib.mkDefault true;

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    }
;}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-16 — this file was a placeholder until this update
#
# From when nire-testbed was added (2026-08-14) until real disk info was read
# off the machine, this file's fileSystems block was invented, not detected:
# `/dev/disk/by-label/TESTBED_ROOT` and `TESTBED_BOOT`, labels that were never
# actually written to any partition, and a generic
# `[ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ]` initrd module list
# that was a guess rather than a scan. Evaluating this host's toplevel during
# that window produced a config for a machine that did not exist yet.
# `nireHost/installer/liveusb-installer.md` documents the live-USB path that
# was meant to replace it -- boot `nire-installer`, partition the real disk,
# run `nixos-generate-config`, and copy its output in, which is what the
# fileSystems/boot.initrd block above now is. See that doc for whether the
# install this depends on has actually been confirmed by a real boot yet, the
# same "undated verified means evaluates, not booted" caveat CLAUDE.md gives
# durandal and tenacity's own first boots.
