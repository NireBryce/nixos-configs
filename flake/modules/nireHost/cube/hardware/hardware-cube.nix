# nire-cube (GMKtec Nucbox G11). fileSystems/boot.initrd.*/swapDevices below
# are real, captured from `nixos-generate-config` after installing NixOS onto
# the real disk with the stock NixOS live ISO -- not this flake's own
# live-USB image (nire-installer, removed 2026-08-27), and not through this
# flake at all -- see the history note at the bottom for what
# stood here before this and why. Cross-checked against the live system's own
# `lsblk -f` while writing this file, not just copied from /etc/nixos blind.
#
# No LUKS, no impermanence: this host was installed with a plain persistent
# btrfs root, not the LUKS + impermanence layout disko-cube.nix (deleted by
# this same change) was speculatively building towards. See
# cube-configuration.nix for why `impermanence` was dropped from this host's
# imports and invariants.nix's "hosts without impermanence opt out" header for
# what that does and doesn't still check on a host like this.
#
# The disk DOES have root/nix/persist/log/home btrfs subvolumes -- whoever
# partitioned this machine by hand used the same subvolume names
# disko-cube.nix's impermanence template would have -- but there is no
# `root-blank` subvolume and nothing here creates the restore-root initrd
# unit, so `/` is never wiped. Don't read the subvolume names as evidence this
# host secretly has impermanence; check for restore-root the way
# invariants.nix and WARN-password-required.nix do, not for subvolume naming.
# There is also no `secureboot` subvolume, unlike durandal's real disk --
# boot-cube.nix still installs sbctl as a package (parity with durandal), it
# just has nowhere dedicated to keep its files.
#
# Wrapped as a flake-parts module for the same reason durandal's/tenacity's
# hardware files are: a raw nixos-generate-config file under modules/ makes
# flake-parts resolve `modulesPath` through its own _module.args and dies with
# "infinite recursion encountered", naming modulesPath rather than this file.
#
# Named hardware-cube.nix, not hardware-configuration.nix: durandal's own
# capture already claims the module name "hardware-configuration", and a
# module's name is its filename -- reusing that name here would merge this
# host's fileSystems into durandal's under the same attribute instead of
# erroring, the same collision tenacity's suffixed filename exists to avoid.
# See CLAUDE.md's new-flake-module trap notes.
{ config, lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, lib, pkgs, modulesPath, ... }:
    {
      imports =
        [ (modulesPath + "/installer/scan/not-detected.nix")
        ];

      boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-amd" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" =
        { device = "/dev/disk/by-uuid/63dae095-fe6b-425e-90ec-5978a475d45e";
          fsType = "btrfs";
          options = [ "subvol=root" "compress=zstd" ];
        };

      fileSystems."/nix" =
        { device = "/dev/disk/by-uuid/63dae095-fe6b-425e-90ec-5978a475d45e";
          fsType = "btrfs";
          options = [ "subvol=nix" "compress=zstd" ];
        };

      fileSystems."/persist" =
        { device = "/dev/disk/by-uuid/63dae095-fe6b-425e-90ec-5978a475d45e";
          fsType = "btrfs";
          options = [ "subvol=persist" "compress=zstd" ];
          neededForBoot = true;
        };

      fileSystems."/var/log" =
        { device = "/dev/disk/by-uuid/63dae095-fe6b-425e-90ec-5978a475d45e";
          fsType = "btrfs";
          options = [ "subvol=log" "compress=zstd" ];
          neededForBoot = true;
        };

      fileSystems."/home" =
        { device = "/dev/disk/by-uuid/63dae095-fe6b-425e-90ec-5978a475d45e";
          fsType = "btrfs";
          options = [ "subvol=home" "compress=zstd" ];
        };

      fileSystems."/boot" =
        { device = "/dev/disk/by-uuid/8857-B380";
          fsType = "vfat";
          options = [ "fmask=0022" "dmask=0022" ];
        };

      swapDevices =
        [ { device = "/dev/disk/by-uuid/0eb40248-55cf-444a-b8ed-ede4c35da60b"; }
        ];

      networking.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    }
;}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-21 -- this file replaces disko-cube.nix
#
# From cube's addition (2026-08-15) until then, this host's hardware module
# was disko-cube.nix: a disko template wiring in
# nire/impermanence/_disko/impermanence-luks-btrfs.nix, with an intentionally
# fake device path ("/dev/disk/by-id/REPLACE-ME-before-running-disko") -- the
# machine hadn't been installed yet. It was installed by hand off the stock
# NixOS live ISO instead (plain persistent root, no LUKS, not through this
# flake), so disko-cube.nix was deleted rather than pointed at a real
# device, and cube-configuration.nix dropped its `impermanence` import to
# match. A future LUKS + impermanence reinstall is a fresh decision, not a
# git-history resurrection: re-derive the device path and layout against
# the disk actually there, the way this file was derived from a real scan
# rather than the old placeholder.
