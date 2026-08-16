# nire-installer: a live-USB NixOS installer image, built specifically to
# install nire-testbed (ThinkPad X270) onto its real disk. See
# `./liveusb-installer.md`, right next to this file, for the full
# boot-to-install walkthrough.
#
# Carries a copy of this whole flake baked into the image itself (see
# `environment.etc."nixos-configs"` below), so booting it is enough on its
# own to run `nixos-install --flake` -- no network, no `git clone`, needed
# just to get the config onto the live system. Network is still needed for
# `nixos-install` itself to pull packages from the binary cache.
#
# Graphical (GNOME live session, not the separate Calamares installer
# wizard -- this still installs by hand-partitioning plus `nixos-install
# --flake`, same as before, not Calamares' own generic-NixOS wizard), with
# `gh` on it. The point of both is the same: a browser to complete `gh auth
# login`'s device-code flow at the actual keyboard, so a real `git clone` of
# this repo -- with push access -- is possible from the live session itself,
# rather than only the read-only embedded copy below. See
# liveusb-installer.md for when to reach for which.
#
# This is not a host anyone switches to or boots persistently -- it exists
# only to produce `config.system.build.isoImage`, which `./installer-iso.nix`
# turns into a `packages.*` output so `nix build .#liveusb-testbed-installer`
# doesn't need anyone to know the nixosConfigurations attribute path by
# heart.
#
# This whole feature -- this file, installer-iso.nix, build-liveusb.sh,
# liveusb-installer.md -- lives together in nireHost/installer/ rather than
# split across modules/scripts/doc the way the rest of the repo is (compare
# durandal-configuration.nix, which sits bare in nireHost/). Deliberate
# grouping, not a new default: nothing else here mixes a script or a doc into
# modules/, and CLAUDE.md's "Every .nix file under modules/ is a flake-parts
# module" is still true of every .nix file in this folder -- import-tree only
# globs *.nix, so the .sh and .md alongside them are simply never seen by it.
# Safe to nest this deep for the same reason: dirsAsCategory only fires where
# a directory holds its own copy of that file, and neither nireHost/ nor
# nireHost/installer/ has one, so nothing collects this folder as a category
# -- it stays reachable only by the literal `installerConfiguration` name
# below, same as every other host entry point.
#
# Wraps the raw upstream installer profile the same way hardware-testbed.nix
# wraps `not-detected.nix`: `modulesPath` only resolves inside the NixOS
# module system, so it has to be an argument of the *inner* module, not
# something reached from this outer flake-parts scope. Importing it at this
# level instead dies with "infinite recursion encountered", naming
# `modulesPath` rather than the real cause -- see CLAUDE.md, "Raw NixOS
# modules in the import-tree path".
#
# Named hardcoded `installerConfiguration` below rather than via the usual
# `moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file)` pattern
# every category member uses -- entry points don't follow that one.
# durandal-configuration.nix declares `durandalConfiguration`, not
# `durandal-configuration`, and hosts.nix looks it up by that literal name;
# this file matches that convention rather than the category one.
{ config, inputs, ... }:
    let
        # Bound out here, before the module body, for the same reason
        # enable-home-manager.nix binds `ellyHome` out here: the inner module
        # below takes its own `lib`/`pkgs`/`modulesPath` args, and if `config`
        # were added to that list too it would silently start meaning the
        # *NixOS* config instead of this flake-parts one, and
        # `config.flake.modules...` would stop resolving. See CLAUDE.md,
        # "There are two different `config`s, and they shadow".
        nixCategory = config.flake.modules.nixos.nix;
    in {
        # `inputs` closes over from this outer scope into the inner module
        # body below, same reason hardware-testbed.nix takes it outside the
        # inner lambda's own arg list -- adding it to that inner arg list
        # instead would shadow it with the *NixOS* module system's own
        # `inputs`-shaped nothing (it isn't a standard module arg there) and
        # break the reference instead of fixing it.
        flake.modules.nixos.installerConfiguration = { lib, pkgs, modulesPath, ... }: {
            imports = [
                # GNOME live session (Firefox, NetworkManager applet, a
                # terminal) -- upstream's own base for the official
                # "graphical" ISO variant. Superset of installation-cd-minimal
                # (still carries nixos-install-tools), swapped in for the
                # browser, needed for `gh auth login`'s device-code flow --
                # see this file's header.
                (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix")

                # flakes + nix-command + allowUnfree + trusted-users=root --
                # same module every real host gets, needed here so
                # `nixos-install --flake` and unfree packages both work from
                # the live environment without extra setup.
                nixCategory
            ];

            networking.hostName = "nire-installer";
            # `isoImage.isoBaseName` until it was renamed upstream. mkForce
            # because installation-cd-base.nix sets this at normal priority
            # (to "nixos-minimal-..."), not mkDefault -- a plain assignment
            # here conflicts instead of overriding it.
            image.baseName = lib.mkForce "nire-installer";

            # No nixpkgs-hostPlatform-<host>.nix here -- this isn't a
            # per-host directory with its own copy of that pattern, just one
            # file. Same value durandal/tenacity/testbed's copies all set.
            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

            # installation-cd-base.nix (which -graphical-base.nix still
            # builds on) defaults to wpa_supplicant-driven
            # `networking.wireless`; the graphical profile likely turns
            # NetworkManager on itself for its own applet, but forcing this
            # explicitly costs nothing and keeps the intent documented either
            # way. NixOS refuses to evaluate with both wireless.enable and
            # networkmanager.enable true at once, so the default has to be
            # forced off rather than merely overridden.
            networking.wireless.enable       = lib.mkForce false;
            networking.networkmanager.enable = true;

            # Firmware for the X270's Intel wireless chip. hardware-testbed.nix
            # doesn't need this (it targets the installed system, which gets
            # its wifi from nixos-hardware's lenovo-thinkpad-x270 module
            # instead) but the installer environment has none of that yet.
            hardware.enableRedistributableFirmware = lib.mkDefault true;

            # Same key list ssh.nix installs for `elly` on every real host,
            # duplicated rather than imported: this ISO has no `elly` user
            # (installation-cd-base.nix's own account is `nixos`, wheel,
            # passwordless sudo) and ssh.nix's authorizedKeys is written onto
            # `users.users.elly` by name. Keep both lists in sync by hand --
            # see nire/system/ssh/ssh.nix if a key is ever added or removed.
            services.openssh.enable = true;
            users.users.nixos.openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILk2lST7kOSRlanAKhl42b9IQib1hzrbxlR5pve/X37D elly@nire-lysithea"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0sEOPmravXojxuKqN3XwplTbuz2p36UDTxmUthktnX elly@durandal"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII/CCC9LRJdjqLqq5t1a0wN1cbw2fmxs2Yxi1grl/nRw elly@nire-sif"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFrut9Gg3TR5omT4yWXBQhifKh6ksT46FWTYA1Gj9YpJ u0_a377@localhost"
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFTe27f8e8B4DpqQYHFK7I7Pg3ZK12W7LqIrdI+ChI1 elly@nire-galatea"
            ];

            # The whole flake, baked into the image -- see this file's header.
            # `inputs.self` is this flake's own outPath, the same value every
            # host's `specialArgs` already gets via hosts.nix's `mkHost`.
            # `environment.etc` symlinks it in from the Nix store, so
            # `/etc/nixos-configs` is real but read-only; `nixos-install
            # --flake path:/etc/nixos-configs#nire-testbed` works straight off
            # it (the `path:` prefix is what lets a plain, non-git directory
            # be used as a flake at all -- see liveusb-installer.md). Editing
            # anything first (a hardware fix, a new host) needs a writable
            # copy: `cp -r /etc/nixos-configs ~/nixos-configs` before editing,
            # same doc.
            environment.etc."nixos-configs".source = inputs.self;

            # installation-cd-minimal.nix (which -graphical-base.nix still
            # carries) already has nixos-install-tools (nixos-generate-config,
            # nixos-install, parted, filesystem tools). These are the extras
            # it doesn't promise: an editor worth using; git, for a real
            # `git clone` with push access once `gh auth login` has run (the
            # embedded /etc/nixos-configs copy below doesn't need it); and gh
            # itself, for that login -- its device-code flow needs a browser,
            # which is the whole reason this image is graphical now.
            environment.systemPackages = with pkgs; [
                git
                gh
                vim
                tmux
                htop
                gptfdisk
                btrfs-progs
            ];
        };
    }
