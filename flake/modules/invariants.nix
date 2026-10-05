# Things that must be TRUE of an evaluated host, not merely resolvable.
#
# checks.nix forces each host's toplevel, catching evaluation errors --
# every defect the flake-parts port produced was one. It cannot catch a
# host that evaluates perfectly and is wrong: a persistence entry dropped
# when a module moved, an initrd unit nothing wants, hibernation creeping
# back onto a machine that cannot survive it -- what tenacity's first
# boot found, about which a green `nix flake check` said nothing
# (wiki/lessons-learned.md §25).
#
# WHY THIS THROWS RATHER THAN FAILING A BUILD
#
# `just check` is `nix flake check --all-systems --no-build`: a
# derivation-shaped check is only *evaluated* -- a runCommand exiting 1
# never runs and never fails. (Also true of the module-tree check, hence
# `just modules` invokes the script directly.) A build-time-only
# invariant would silently pass every time -- the failure mode this file
# stops; failing during evaluation is what makes --no-build sufficient.
# The whole failure list is built before anything throws, so one run
# reports every broken invariant on every host.
#
# WHERE IT ACTUALLY RUNS
#
# Useful from darwin, unlike the host checks: `--all-systems` evaluates
# every system's checks, and these throw during evaluation, so `just
# check` on lysithea enforces every NixOS host -- evaluation is this
# machine's only lever on hosts it cannot build. The aarch64-darwin
# instance is vacuous (filters nixosConfigurations by system; lysithea
# is a darwinConfiguration, so "0 invariants held across 0 host(s)") --
# do not "fix" that by dropping the system filter: the host attributes
# below are NixOS-only, and a darwin host would fail on the option
# paths, not on the invariants.
#
# Sits at the top of modules/, outside every category directory, so no
# dirsAsCategory collects it; it declares no flake.modules.<class>
# attribute, so modules.py does not consider it for orphans either.
#
# OPT-IN: HOSTS WITHOUT IMPERMANENCE ARE EXEMPT
#
# The root-rollback, hibernation and persistence groups apply only to
# hosts that opted into impermanence, gated on
# `boot.initrd.systemd.services ? restore-root` -- the unit
# WARN-impermanence.nix creates and nothing else does. Originally
# (pre-nire-testbed, since removed) unconditional, because both hosts
# then wiped `/root`; nire-cube is the current counterexample -- checking
# it would fail every boot and never catch a real regression.
#
# The gate is the unit's *existence*, deliberately not a marker option
# and deliberately not `environment.persistence ? "/persist"` --
# general-config/system/impermanence/declare-persistence-option.nix now declares
# that option on every NixOS host so tailscale-persist.nix and
# jovian-persist.nix have somewhere valid to write even when they write
# nothing; it no longer distinguishes an impermanence host from one
# merely declaring the option. restore-root is the one thing only
# WARN-impermanence.nix creates. (The *-persist.nix modules --
# tailscale, mullvad, networkmanager, libvirt -- and
# WARN-password-required.nix gate on the same check; tailscale-persist.nix
# explains why.)
#
# No weakening of what the file catches: a host silently losing part of
# its OWN impermanence setup while restore-root exists -- wantedBy
# dropped, hibernation creeping back, a persistence entry lost -- still
# trips these invariants, the gate staying true and every sub-check
# running. Only a host that never claimed impermanence escapes, and that
# was never a regression.
#
# The useGlobalPkgs invariant is NOT gated on usesImpermanence -- it
# holds for every NixOS host, cube included. It IS gated on the host
# having home-manager at all (`c ? home-manager`). forge-runner (the
# guest VM cube runs) is the current host without it: no `elly` user, no
# home-manager closure, so it never imports enable-home-manager.nix and
# has no `home-manager` namespace. The gate was added for nire-installer
# (live-USB image, removed 2026-08-27); nire-llm-sandbox (a libvirt VM
# image, removed 2026-08-28) was the same shape. Same principle as the
# impermanence gate -- check the real thing's existence, not the host's
# name -- and not vacuous: enable-home-manager.nix is the only NixOS-side
# setter of useGlobalPkgs (enable-home-manager-darwin.nix is lysithea's,
# outside this file's reach), but a later import flipping it back to
# false on a host that DOES have home-manager is exactly the regression
# this still catches.
#
# HOST-WIDE AND PER-USER GROUPS (2026-09-27)
#
# hostInvariants apply to every NixOS host, each one gated on the thing
# it guards existing there (u2f on, a vfat /boot, systemd-boot) rather
# than on a host name -- forge-runner has none of those and passes them
# vacuously. ellyInvariants are gated on `users.users ? elly`, which
# forge-runner also lacks. Considered and left out: firewall port pins
# (hardcode nixpkgs' port numbers, visible to a scan anyway), hostName
# matching the flake attribute (loud at the prompt), sessionPath
# duplicates (harmless).
{ config, lib, ... }:
{
    perSystem = { system, pkgs, ... }:
    let
        hostsForThisSystem = lib.filterAttrs
            (_: host: host.config.nixpkgs.hostPlatform.system == system)
            config.flake.nixosConfigurations;

        # `directories` is `listOf (either str (submodule ...))`, both
        # forms occur after merging, so normalise before comparing. Same
        # for `files` -- its submodule names the attribute `file`, not
        # `directory`.
        persistDirs = c:
            map (d: if lib.isString d then d else d.directory)
                (c.environment.persistence."/persist".directories or []);
        persistFiles = c:
            map (f: if lib.isString f then f else f.file)
                (c.environment.persistence."/persist".files or []);

        # Every invariant is `{ ok; msg; }`; msg says what breaks, not
        # what differs -- read by someone who doesn't yet know why the
        # line existed.
        invariantsFor = name: host:
        let
            c        = host.config;
            dirs     = persistDirs c;
            files    = persistFiles c;
            rollback = c.boot.initrd.systemd.services.restore-root or null;
            hhd      = c.services.handheld-daemon.enable or false;

            # restore-root existing is what marks a host as having opted
            # into impermanence -- see the header, "OPT-IN: HOSTS WITHOUT
            # IMPERMANENCE ARE EXEMPT", for why this is the gate.
            usesImpermanence = rollback != null;

            # Whether this host imported enable-home-manager.nix at all --
            # see the header's opt-in addendum. forge-runner has no `elly`
            # user and doesn't; nire-installer and nire-llm-sandbox (both
            # removed) were the same shape.
            usesHomeManager = c ? home-manager;

            # Absent on forge-runner (no `elly` user); see the header's
            # HOST-WIDE AND PER-USER GROUPS.
            usesElly = c.users.users ? elly;

            sleep    = c.systemd.sleep.settings.Sleep or { };
            sleepOn  = lib.filter (k: (sleep.${k} or true) != false)
                           [ "AllowHibernation" "AllowHybridSleep" "AllowSuspendThenHibernate" ];

            # Every openssh host key, private and public half. Derived from
            # hostKeys rather than listing paths, so a changed key set is
            # checked as it is, not as it was.
            sshKeyFiles = lib.concatMap (k: [ k.path "${k.path}.pub" ])
                              (c.services.openssh.hostKeys or [ ]);
            sopsKeys    = c.sops.age.sshKeyPaths or [ ];

            # Lines of every rendered PAM service that load pam_u2f.
            u2fLines = lib.concatMap
                (s: lib.filter (lib.hasInfix "pam_u2f.so")
                        (lib.splitString "\n" (if (s.text or null) == null then "" else s.text)))
                (lib.attrValues (c.security.pam.services or { }));

            userList   = lib.attrValues (c.users.users or { });
            anyAutoSub = lib.any (u: u.autoSubUidGidRange or false) userList;
            anyPinSub  = lib.any (u: (u.subUidRanges or [ ]) != [ ] || (u.subGidRanges or [ ]) != [ ]) userList;

            boot     = c.fileSystems."/boot" or null;
            bootOpts = if boot == null then [ ] else boot.options or [ ];
            vfatBoot = boot != null && (boot.fsType or "") == "vfat";

            impermanenceInvariants = [
            # -- the root rollback actually runs ------------------------------
            #
            # The one that matters most, with no runtime symptom until too
            # late: if restore-root stops being pulled in, / simply stops
            # being wiped and the machine looks fine.
            {
                ok  = rollback != null;
                msg = "${name}: boot.initrd.systemd.services.restore-root is gone -- "
                    + "/ would no longer roll back to root-blank, and nothing else reports that";
            }
            {
                ok  = rollback == null || lib.elem "initrd.target" (rollback.wantedBy or []);
                msg = "${name}: restore-root exists but nothing wants it (wantedBy lacks "
                    + "initrd.target), so it is built and never started";
            }
            {
                ok  = rollback == null || lib.elem "sysroot.mount" (rollback.before or []);
                msg = "${name}: restore-root is not ordered before sysroot.mount -- the wipe "
                    + "could run after / is already mounted";
            }
            {
                # postResumeCommands (scripted stage 1) and an initrd
                # systemd unit are mutually exclusive. If this flips
                # false the unit above stops existing rather than
                # misbehaving -- this invariant explains the previous
                # three when they go.
                ok  = c.boot.initrd.systemd.enable;
                msg = "${name}: boot.initrd.systemd.enable is false, but the rollback is a "
                    + "systemd stage-1 unit -- see WARN-impermanence.nix";
            }
            {
                # supportedFilesystems is `attrsOf bool` now and only
                # *accepts* the list form WARN-impermanence.nix writes;
                # read back it is { btrfs = true; }. Both shapes handled
                # because reading it as a list is an error, not a false
                # negative -- and that error names nixpkgs, not this file.
                ok  = let sf = c.boot.initrd.supportedFilesystems or { }; in
                      if lib.isList sf then lib.elem "btrfs" sf else (sf.btrfs or false);
                msg = "${name}: btrfs missing from boot.initrd.supportedFilesystems -- the "
                    + "rollback shells out to btrfs, which reaches initrdBin through this";
            }

            # -- hibernation stays off ---------------------------------------
            #
            # A hibernation image is a snapshot of a system whose / is
            # about to be deleted underneath it. Disabling it also broke
            # suspend outright once; both halves recorded in
            # WARN-impermanence.nix.
            {
                ok  = lib.elem "nohibernate" (c.boot.kernelParams or []);
                msg = "${name}: nohibernate missing from boot.kernelParams -- impermanence "
                    + "cannot survive resuming into a / that was rolled back";
            }
            {
                # All three, not just AllowHibernation: HybridSleep and
                # SuspendThenHibernate both write a hibernation image too,
                # and PowerDevil asking for a state logind no longer offers
                # is how suspend silently stopped working once (§30).
                ok  = sleepOn == [ ];
                msg = "${name}: systemd.sleep.settings.Sleep.{${lib.concatStringsSep "," sleepOn}} "
                    + "not false -- logind still offers a sleep state that writes a "
                    + "hibernation image the kernel will refuse (§30)";
            }

            # -- persistence -------------------------------------------------
            {
                # /persist has to be up in stage 1: machine-id, the ssh host
                # keys and the password hash are bind-mounted from it before
                # anything reads them. disko does not set this; each host's
                # hardware file adds it by hand.
                ok  = c.fileSystems."/persist".neededForBoot or false;
                msg = "${name}: fileSystems.\"/persist\".neededForBoot is not true -- /persist "
                    + "mounts after stage 1, too late for everything persisted from it";
            }
            {
                ok  = toString (c.environment.etc."machine-id".source or "") == "/persist/etc/machine-id";
                msg = "${name}: /etc/machine-id no longer sourced from /persist -- a new "
                    + "machine-id every boot, so journalctl --list-boots silently shows only "
                    + "the current boot (the journal directory is per machine-id)";
            }
            {
                ok  = lib.elem "/var/lib/tailscale" dirs;
                msg = "${name}: /var/lib/tailscale not persisted -- tailscale needs "
                    + "re-authenticating on every boot (see tailscale-persist.nix)";
            }
            {
                # Replaced a hardcoded ed25519+rsa list (2026-09-27), which
                # could not see a change to hostKeys and skipped the .pub
                # halves.
                ok  = lib.all (f: lib.elem f files) sshKeyFiles;
                msg = "${name}: ssh host keys not persisted ("
                    + lib.concatStringsSep ", " (lib.filter (f: !lib.elem f files) sshKeyFiles)
                    + ") -- the host identity changes on every boot and every client "
                    + "warns about a changed key";
            }
            {
                # Same paths as the ed25519 host key today (sops.nix derives
                # them from hostKeys); checked separately because the
                # consumer is different and so is the failure.
                ok  = lib.all (f: lib.elem f files) sopsKeys;
                msg = "${name}: a sops.age.sshKeyPaths entry is not persisted -- every "
                    + "sops secret fails to decrypt at activation after the boot that wiped it";
            }

            # Each *-persist.nix sibling, checked against the service that
            # owns the state rather than against the file that persists it:
            # the sibling is gated only on restore-root, so this is what
            # notices a service whose state nobody persists.
            {
                ok  = !(c.networking.networkmanager.enable or false)
                      || (lib.elem "/etc/NetworkManager/system-connections" dirs
                          && lib.elem "/var/lib/NetworkManager/secret_key" files);
                msg = "${name}: NetworkManager runs but its connections or secret_key are not "
                    + "persisted -- saved networks and their secrets are lost every boot";
            }
            {
                ok  = !(c.services.mullvad-vpn.enable or false) || lib.elem "/etc/mullvad-vpn" dirs;
                msg = "${name}: mullvad-vpn runs but /etc/mullvad-vpn is not persisted -- the "
                    + "device registration is lost every boot";
            }
            {
                # Vacuous today: libvirtd runs only on cube, which does not
                # wipe /. Break-tested 2026-09-27 by enabling libvirtd on
                # durandal; kept for the first impermanence host that runs it.
                ok  = !(c.virtualisation.libvirtd.enable or false)
                      || lib.elem "/var/lib/libvirt/secrets/secrets-encryption-key" files;
                msg = "${name}: libvirtd runs but its secrets-encryption-key is not persisted -- "
                    + "every libvirt secret it encrypted becomes unreadable after a boot";
            }
            {
                # States the scoping rule, not the hosts, so it keeps
                # holding when a second handheld appears. Both directions
                # matter: a handheld silently losing its fan curves, and
                # durandal quietly acquiring a rule for a daemon it never
                # runs.
                ok  = lib.elem "/etc/hhd" dirs == hhd;
                msg = if hhd
                      then "${name}: runs handheld-daemon but does not persist /etc/hhd -- fan "
                         + "curves and TDP profiles reset on every boot"
                      else "${name}: persists /etc/hhd but runs no handheld-daemon -- "
                         + "jovian-persist.nix has escaped its category";
            }
            ];
            homeManagerInvariants = [
            {
                # HM *rejects* every nixpkgs.* option under useGlobalPkgs
                # rather than ignoring it, so this flipping does not degrade
                # quietly -- but allowUnfree comes from the system side
                # because of it, and that is the part that would go strange.
                ok  = c.home-manager.useGlobalPkgs or false;
                msg = "${name}: home-manager.useGlobalPkgs is false -- HM would build its own "
                    + "nixpkgs and lose the system's allowUnfree";
            }
        ];
            hostInvariants = [
            {
                # Reads the rendered PAM text, not the option: settings is
                # freeform, so a misspelled key evaluates clean and pam_u2f
                # discards it as an unknown argument. `authFile=` did exactly
                # that for five months, masked by matching pam_u2f's
                # default path (§49, yubikey.nix).
                ok  = !(c.security.pam.u2f.enable or false)
                      || (u2fLines != [ ]
                          && lib.all (l: lib.hasInfix " authfile=" l && !lib.hasInfix "authFile=" l) u2fLines);
                msg = "${name}: a rendered pam_u2f line lacks authfile= (or carries the camelCase "
                    + "authFile=, which pam_u2f ignores) -- u2f silently falls back to its "
                    + "built-in key path (§49)";
            }
            {
                # nixpkgs' auto allocator never looks at pinned ranges, so a
                # host mixing the two hands both users 100000:65536 on a
                # fresh install (podman.nix, "NOT autoSubUidGidRange"; §32).
                ok  = !(anyAutoSub && anyPinSub);
                msg = "${name}: a user has autoSubUidGidRange while another has pinned "
                    + "subUidRanges/subGidRanges -- the allocator cannot see the pins, and a "
                    + "fresh install gives two users one subordinate range (§32)";
            }
            {
                # nixpkgs mounts vfat /boot 0022 when no options are given;
                # durandal did, and bootctl logged /boot/loader/random-seed
                # as world accessible (08098b13). Set per host in each
                # hardware file, so a new or regenerated one drops it.
                ok  = !vfatBoot
                      || lib.elem "umask=0077" bootOpts
                      || (lib.elem "fmask=0077" bootOpts && lib.elem "dmask=0077" bootOpts);
                msg = "${name}: vfat /boot mounted without fmask=0077,dmask=0077 -- the loader "
                    + "entries and random-seed are readable by every local user";
            }
            {
                # nixpkgs defaults this to true; boot-editor.nix sets it once
                # for every host through the `boot` category, so losing that
                # import is silent. On cube (no LUKS) an editable command line
                # is a root shell over the whole disk.
                ok  = !(c.boot.loader.systemd-boot.enable or false)
                      || !(c.boot.loader.systemd-boot.editor or true);
                msg = "${name}: systemd-boot's editor is on -- anyone at the console can boot "
                    + "with init=/bin/sh (see boot-editor.nix)";
            }
            ];
            ellyInvariants = [
            {
                ok  = !c.users.mutableUsers
                      && lib.hasPrefix "/persist/" (toString (c.users.users.elly.hashedPasswordFile or ""));
                msg = "${name}: users.mutableUsers is true or elly's hashedPasswordFile is outside "
                    + "/persist -- passwd changes revert on switch, or a host that wipes / "
                    + "loses the hash and locks the user out (elly-user.nix, "
                    + "WARN-password-required.nix)";
            }
            ];
        in
            (if usesImpermanence then impermanenceInvariants else [ ])
            # NOT gated on usesImpermanence: holds for every NixOS host
            # that has home-manager at all, cube included. See
            # usesHomeManager for what a host without one looks like --
            # forge-runner is one.
            ++ (if usesHomeManager then homeManagerInvariants else [ ])
            ++ hostInvariants
            ++ (if usesElly then ellyInvariants else [ ]);

        failures = lib.concatLists (lib.mapAttrsToList
            (name: host: lib.filter (i: !i.ok) (invariantsFor name host))
            hostsForThisSystem);

        total = lib.length (lib.concatLists (lib.mapAttrsToList
            invariantsFor hostsForThisSystem));
    in
    {
        checks.invariants =
            if failures == []
            then pkgs.runCommand "invariants" { }
                 "echo '${toString total} invariants held across ${
                     toString (lib.length (lib.attrNames hostsForThisSystem))
                  } host(s)' > $out"
            else throw ("invariants failed:\n"
                 + lib.concatMapStringsSep "\n" (i: "  - ${i.msg}") failures
                 # Where to go from here (#460): the reason for each is the
                 # comment above it, and §N is wiki/lessons-learned.md.
                 + "\n  -> why each holds: the comment above it in flake/modules/invariants.nix;"
                 + " impermanence ones: skill impermanence-initrd and WARN-impermanence.nix;"
                 + " §N: wiki/lessons-learned.md (§25: a clean eval says nothing about these)\n");
    };
}
