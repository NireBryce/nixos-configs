# Things that must be TRUE of an evaluated host, not merely resolvable.
#
# checks.nix forces each host's toplevel, catching evaluation errors --
# every defect the flake-parts port produced was one. It cannot catch a
# host that evaluates perfectly and is wrong: a persistence entry dropped
# when a module moved, an initrd unit nothing wants, hibernation creeping
# back onto a machine that cannot survive it -- what tenacity's first
# boot found, about which a green `nix flake check` said nothing
# (lessons.md 25).
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
# check` on lysithea enforces both Linux hosts -- evaluation is this
# machine's only lever on hosts it cannot build. The aarch64-darwin
# instance is vacuous (filters nixosConfigurations by system; lysithea
# is a darwinConfiguration, so "0 invariants held across 0 host(s)") --
# do not "fix" that by dropping the system filter: the host attributes
# below are NixOS-only, and a darwin host would fail on the option
# paths, not on the invariants.
#
# Sits at the top of modules/ (dirsAsCategory walks subdirectories only,
# so it is not collected); it declares no flake.modules.<class>
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
# nire/system/impermanence/declare-persistence-option.nix now declares
# that option on every NixOS host so tailscale-persist.nix and
# jovian-persist.nix have somewhere valid to write even when they write
# nothing; it no longer distinguishes an impermanence host from one
# merely declaring the option. restore-root is the one thing only
# WARN-impermanence.nix creates. (tailscale-persist.nix is gated on the
# same check -- see that file.)
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
# having home-manager at all (`c ? home-manager`), added for
# nire-installer (live-USB image, removed 2026-08-27): no `elly` user,
# no home-manager closure, so it never imported enable-home-manager.nix
# and had no `home-manager` namespace; nire-llm-sandbox (a libvirt VM
# image, removed 2026-08-28) was the same shape. Kept general rather than
# special-cased to either, since every host currently in hosts.nix does
# have home-manager. Same principle as the impermanence gate -- check the
# real thing's existence, not the host's name -- and not vacuous:
# enable-home-manager.nix is the only setter of useGlobalPkgs, but a
# later import flipping it back to false on a host that DOES have
# home-manager is exactly the regression this still catches.
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
            # see the header's opt-in addendum. nire-installer (removed
            # 2026-08-27) and nire-llm-sandbox (removed 2026-08-28) both had
            # no `elly` user and never did; no host currently in hosts.nix
            # is this shape, but the gate stays general for the next one
            # that is.
            usesHomeManager = c ? home-manager;

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
                    + "systemd stage-1 unit -- see flake/doc/impermanence-stage1.md";
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
                ok  = (c.systemd.sleep.settings.Sleep.AllowHibernation or true) == false;
                msg = "${name}: systemd.sleep.settings.Sleep.AllowHibernation is not false, so "
                    + "logind still offers an option the kernel will refuse";
            }

            # -- persistence -------------------------------------------------
            {
                ok  = lib.elem "/var/lib/tailscale" dirs;
                msg = "${name}: /var/lib/tailscale not persisted -- tailscale needs "
                    + "re-authenticating on every boot (see tailscale-persist.nix)";
            }
            {
                ok  = lib.all (f: lib.elem f files) [
                          "/etc/ssh/ssh_host_ed25519_key"
                          "/etc/ssh/ssh_host_rsa_key"
                      ];
                msg = "${name}: ssh host keys not persisted -- the host identity changes on "
                    + "every boot and every client warns about a changed key";
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
        in
            (if usesImpermanence then impermanenceInvariants else [ ])
            # NOT gated on usesImpermanence: holds for every NixOS host
            # that has home-manager at all, cube included. See
            # usesHomeManager for what a host without one looks like --
            # none currently in hosts.nix is, but nire-llm-sandbox (removed
            # 2026-08-28) was.
            ++ (if usesHomeManager then homeManagerInvariants else [ ]);

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
                 + "\n");
    };
}
