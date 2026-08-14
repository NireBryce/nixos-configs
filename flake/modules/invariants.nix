# Things that must be TRUE of an evaluated host, not merely resolvable.
#
# checks.nix forces each host's toplevel, which catches evaluation errors --
# every defect the flake-parts port produced was one. It cannot catch a host
# that evaluates perfectly and is wrong: a persistence entry dropped when a
# module moved, an initrd unit that stopped being wanted by anything,
# hibernation creeping back onto a machine that cannot survive it. Those are
# the ones the first boot on tenacity found, and a green `nix flake check` said
# nothing about any of them (lessons.md 25).
#
# WHY THIS THROWS RATHER THAN FAILING A BUILD
#
# `just check` is `nix flake check --all-systems --no-build`. Under --no-build a
# derivation-shaped check is only *evaluated* -- the log says "derivation
# evaluated to ..." and stops -- so a runCommand that exits 1 never runs and
# never fails. That is also true of the module-tree check next door, which is
# why `just modules` invokes the script directly instead of relying on the flake
# check. An invariant that only fails at build time would silently pass here
# every single time, which is precisely the failure mode this file exists to
# stop. Failing during evaluation is what makes --no-build sufficient.
#
# The whole failure list is built before anything throws, so one run reports
# every broken invariant across every host rather than only the first.
#
# WHERE IT ACTUALLY RUNS
#
# Unlike the host checks, this is useful from darwin. `--all-systems` evaluates
# every system's checks regardless of the machine doing the evaluating, and
# these throw during evaluation, so `just check` on lysithea enforces both Linux
# hosts. That is the point: durandal and tenacity cannot be built from here, so
# evaluation is the only lever this machine has on them.
#
# The aarch64-darwin instance is consequently vacuous -- it filters
# nixosConfigurations by system and lysithea is a darwinConfiguration, so it
# reports "0 invariants held across 0 host(s)" and passes. That is honest rather
# than broken. Do not "fix" it by dropping the system filter; the host attributes
# below are NixOS-only and a darwin host would fail on the option paths, not on
# the invariants.
#
# Sits at the top of modules/ so dirsAsCategory does not collect it -- that
# walks subdirectories only. It declares no flake.modules.<class> attribute, so
# it is not a module and modules.py does not consider it for orphans either.
{ config, lib, ... }:
{
    perSystem = { system, pkgs, ... }:
    let
        hostsForThisSystem = lib.filterAttrs
            (_: host: host.config.nixpkgs.hostPlatform.system == system)
            config.flake.nixosConfigurations;

        # `directories` is `listOf (either str (submodule ...))` and both forms
        # occur after merging, so normalise before comparing. Same for `files`,
        # whose submodule names the attribute `file` rather than `directory`.
        persistDirs = c:
            map (d: if lib.isString d then d else d.directory)
                (c.environment.persistence."/persist".directories or []);
        persistFiles = c:
            map (f: if lib.isString f then f else f.file)
                (c.environment.persistence."/persist".files or []);

        # Every invariant is `{ ok; msg; }`. msg says what breaks, not what
        # differs -- a failure here is read by someone who does not yet know why
        # the line existed.
        invariantsFor = name: host:
        let
            c        = host.config;
            dirs     = persistDirs c;
            files    = persistFiles c;
            rollback = c.boot.initrd.systemd.services.restore-root or null;
            hhd      = c.services.handheld-daemon.enable or false;
        in
        [
            # -- the root rollback actually runs ------------------------------
            #
            # This is the one that matters most and the one with no runtime
            # symptom until it is too late: if restore-root stops being pulled
            # in, / simply stops being wiped and the machine looks fine.
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
                # postResumeCommands (scripted stage 1) and an initrd systemd
                # unit are mutually exclusive mechanisms. If this flips false the
                # unit above stops existing rather than misbehaving, so this is
                # the invariant that explains the previous three when they go.
                ok  = c.boot.initrd.systemd.enable;
                msg = "${name}: boot.initrd.systemd.enable is false, but the rollback is a "
                    + "systemd stage-1 unit -- see flake/doc/impermanence-stage1.md";
            }
            {
                # supportedFilesystems is `attrsOf bool` now and only *accepts*
                # the list form WARN-impermanence.nix writes; by the time it is
                # read back it is { btrfs = true; }. Both shapes are handled
                # because reading it as a list is an error, not a false
                # negative, and that error names nixpkgs rather than this file.
                ok  = let sf = c.boot.initrd.supportedFilesystems or { }; in
                      if lib.isList sf then lib.elem "btrfs" sf else (sf.btrfs or false);
                msg = "${name}: btrfs missing from boot.initrd.supportedFilesystems -- the "
                    + "rollback shells out to btrfs, which reaches initrdBin through this";
            }

            # -- hibernation stays off ---------------------------------------
            #
            # A hibernation image is a snapshot of a system whose / is about to
            # be deleted underneath it. Disabling it also broke suspend outright
            # once; both halves are recorded in WARN-impermanence.nix.
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
                # States the scoping rule rather than the hosts, so it keeps
                # holding when a second handheld appears. Both directions matter:
                # a handheld silently losing its fan curves, and durandal quietly
                # acquiring a rule for a daemon it never runs.
                ok  = lib.elem "/etc/hhd" dirs == hhd;
                msg = if hhd
                      then "${name}: runs handheld-daemon but does not persist /etc/hhd -- fan "
                         + "curves and TDP profiles reset on every boot"
                      else "${name}: persists /etc/hhd but runs no handheld-daemon -- "
                         + "jovian-persist.nix has escaped its category";
            }

            # -- home manager ------------------------------------------------
            {
                # HM *rejects* every nixpkgs.* option under useGlobalPkgs rather
                # than ignoring it, so this flipping does not degrade quietly --
                # but allowUnfree comes from the system side because of it, and
                # that is the part that would go strange.
                ok  = c.home-manager.useGlobalPkgs or false;
                msg = "${name}: home-manager.useGlobalPkgs is false -- HM would build its own "
                    + "nixpkgs and lose the system's allowUnfree";
            }
        ];

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
