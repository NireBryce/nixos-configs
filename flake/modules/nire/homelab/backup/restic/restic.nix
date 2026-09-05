# restic: cube's only backup of its own service state, to the QNAP NAS
# already on the network. Added 2026-08-28 against issue #87 ("no backups
# anywhere in the fleet") and the original plan, folded into
# `wiki/homelab/backup-runbook.md`'s "Background" section 2026-09-02 when
# `claude cave/` was retired -- read that section for the reasoning this
# header only summarizes. Own category
# (`nire/homelab/backup/`), not `restic`: a category and its one module both
# named `restic` would declare `flake.modules.nixos.restic` twice and
# silently MERGE, the `containers`/`podman.nix` collision CLAUDE.md/AGENTS.md
# document -- same reason `git-forge` isn't `forgejo`.
#
# REPOSITORY IS SFTP NOW, NOT A LOCAL PATH ON THE NFS MOUNT -- reversed
# 2026-08-31 from the local-path-on-NFS choice this module shipped with.
# That choice was deliberate (see history below for the original reasoning
# and issue #87's own alternative), but it depended on the QNAP's NFS
# export ACL for `restic-backup`, and that turned out not to work: a real
# switch on cube (below) hit `mount.nfs: access denied by server`, live,
# not hypothetical. Chasing that down (QNAP admin console has no menu for
# forcing key-only SSH, so plain host-IP-allowlist NFS access was already
# the weaker of the two anyway) led to just enabling SSH on the QNAP and
# using it directly, which is what issue #87 originally suggested. SFTP
# gets real per-connection key auth instead of NFS's host-IP allowlist --
# strictly better on the one axis that mattered here, and doesn't depend
# on `storage-NFS.nix`'s mount succeeding at all anymore. That mount still
# exists in the tree (nothing else stopped using it), just not for this.
#
# THE KEY IS DEDICATED, NOT REUSED. Generated on cube specifically for this
# (`~/.ssh/restic-cube-backup`, ed25519, no passphrase -- it has to work
# unattended from a systemd unit), not the personal `elly@nire-cube` key
# that already had QNAP access for interactive admin use. Public half
# appended to the QNAP's `nire` user's `~/.ssh/authorized_keys` directly
# (confirmed working: `ssh -i ~/.ssh/restic-cube-backup nire@ts-hive`
# authenticates with no password prompt). Private half has to reach
# secrets.yaml the same way restic-cube-password did -- see that secret's
# own comment below for why this session can't do that step itself.
#
# THE QNAP'S HOST KEY IS PINNED, NOT TRUST-ON-FIRST-USE: `programs.ssh.
# knownHosts` below, captured via `ssh-keyscan` against the real host and
# checked into the tree, rather than `StrictHostKeyChecking=accept-new` at
# connection time. A stale or spoofed host key fails loud at connection
# time instead of silently trusting whatever answers on first contact.
#
# NOTHING HERE HAS BEEN VERIFIED PAST EVALUATION for the SFTP switch
# specifically -- the connection itself was tested by hand (see above), but
# this module hasn't been built or switched since. The build/secret saga
# below is about the NFS-era version of this module; treat it as history,
# not current status.
#
# REPOSITORY MOVED OFF `nire`'S HOME, 2026-09-03 -- the QNAP's Snapshot
# Manager (checked directly, screenshot in the session that made this
# change) showed the anti-deletion mitigation below would have to target
# the `homes` share to cover `/share/homes/nire/restic-cube`, and QNAP
# snapshots are per-shared-folder: that would snapshot every user's home
# directory on the NAS, not just this repo. `restic-backup` already exists
# as its own share (Storage Pool 2, unused since the abandoned NFS plan --
# see history below), so the repo now points there instead. UNVERIFIED:
# whether the `nire` SFTP account actually has write access to
# `restic-backup` (it was provisioned for NFS-era access, not SFTP to this
# path) and whether anything was ever backed up to the old
# `/share/homes/nire/restic-cube` path that needs migrating rather than
# starting fresh -- neither has been checked against the real QNAP. Confirm
# both by hand before trusting a build against this path; see sftpRepo's
# own comment for the exact check.
#
# ── history: NFS era, 2026-08-28 through 2026-08-31 ──────────────────────
#
# THE PLAN DOC'S "storage-NFS.nix IS DANGLING" CLAIM WAS WRONG, corrected
# while writing this module rather than left to rot: `nire/system/storage/`
# has no `dirsAsCategory.nix` of its own, so `storage-NFS.nix` is collected
# straight into the shared `system` aggregate (see
# `flake/modules/_lib/category-collector.nix`) -- which every Linux host
# imports. `nix eval .#nixosConfigurations.<host>.config.fileSystems` on all
# three (durandal, tenacity, cube) listed `/mnt/qnap-erin`, checked
# 2026-08-28 (the mount point was renamed to `/mnt/restic-backup`, a share
# dedicated to this module, shortly after). So the QNAP NFS mount was
# ALREADY live everywhere, not an unused module one import away.
#
# The original repository choice was a local path on that mount, not SFTP
# -- deliberately different from issue #87's original sketch, on the
# reasoning that restic encrypts client-side regardless of backend, so a
# local-path repo gets the same encryption-at-rest without standing up
# SSH/`rest-server`/Container Station on the QNAP. Stated then as the one
# real trade-off in the module: NFS export trust is IP-based, not keyed.
# That trade-off is what ended up mattering -- see the new header above.
#
# A real build on cube (synced over ssh, twice -- darwin can't cross-build
# x86_64-linux, AGENTS.md Commands) first failed on `sops.secrets.
# restic-cube-password` having no value in the secrets.yaml that attempt
# had -- a BUILD-time failure (sops-nix validates its manifest as part of
# `system.build.toplevel`), not just a runtime one. The password already
# existed, set via `sops set` against a separate checkout on cube
# (`~/projects/nix/nixos-configs`) the first attempt hadn't checked --
# merging that checkout's secrets.yaml in and rebuilding gave a clean full
# toplevel. Cube was later switched (not by an agent session -- `sudo`
# there needs a password one doesn't have) to a generation with this
# module, and the NFS mount failed exactly the way described above.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # `restic-backup`, the QNAP's own dedicated share (Storage Pool 2),
        # not `nire`'s home -- see the module header's 2026-09-03 entry for
        # why this moved off `/share/homes/nire/restic-cube`. `cube`
        # underneath it is a host-scoped subdirectory for the same reason
        # the old NFS `repoRoot` had one: nothing stops another host
        # getting its own backup category later, and this keeps
        # repositories from colliding if one does.
        #
        # NOT CONFIRMED LIVE -- the old home-directory path was checked by
        # hand (`ssh nire@ts-hive 'echo $HOME'`); this one hasn't been.
        # Before building against it: confirm `nire` can write here
        # (`ssh nire@ts-hive 'mkdir -p /share/restic-backup/cube && chmod
        # 700 /share/restic-backup/cube'` -- restic's SFTP backend needs
        # the parent directory to exist even though it creates the
        # repository structure itself on `init`) and that
        # `/share/homes/nire/restic-cube` (the old path) has nothing
        # already backed up to it that would need migrating instead of a
        # fresh `init` here.
        sftpRepo          = "sftp:nire@ts-hive:/share/restic-backup/cube";
        sqliteStagingDir  = "/var/cache/restic-backups-cube/sqlite-staging";

        # The three sqlite dbs actually at risk (issue #87's table), and
        # where each one lives -- checked against the pinned nixpkgs
        # modules rather than assumed: forgejo.nix's `stateDir` defaults to
        # `/var/lib/forgejo`, db at `${stateDir}/data/forgejo.db`
        # (nixos/modules/services/misc/forgejo.nix); grafana's `dataDir`
        # defaults to `/var/lib/grafana`, db at `${dataDir}/data/grafana.db`
        # (nixos/modules/services/monitoring/grafana.nix); golink's db path
        # is hardcoded in this repo's own golink.nix (`-sqlitedb
        # ${stateDir}/golink.db`, stateDir `/var/lib/golink`, the
        # DynamicUser symlink to `/var/lib/private/golink`) since there's
        # no upstream NixOS module to read a default from.
        sqliteDbs = {
            forgejo = "/var/lib/forgejo/data/forgejo.db";
            grafana = "/var/lib/grafana/data/grafana.db";
            golink  = "/var/lib/golink/golink.db";
        };
    in {
        # `config` and `pkgs` bound HERE, on the inner NixOS-module
        # function, not the outer flake-parts one -- flake-parts doesn't
        # inject a `pkgs` into `_module.args` at that scope (evaluating it
        # errors: "attribute 'pkgs' missing"), and the outer `config` is
        # the flake-parts config, not this option tree. Same pattern
        # grafana.nix/golink.nix/forgejo.nix use.
        flake.modules.nixos.${moduleName} = { config, pkgs, ... }: {
            # Pinned host key, not TOFU -- see the module header. Captured
            # 2026-08-31 via `ssh-keyscan -t ed25519 ts-hive` against the
            # real host. `programs.ssh.knownHosts` writes this into
            # `/etc/ssh/ssh_known_hosts` (system-wide), which any `ssh`
            # invocation on this host consults by default -- including the
            # one `sftp.command` below shells out to -- so no
            # `-o UserKnownHostsFile=`/`-o StrictHostKeyChecking=` is
            # needed on that command line.
            programs.ssh.knownHosts."ts-hive".publicKey =
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFyg7GFh4XWohudoODsdbzj8MtyymHChvk/BHvm+IRDU";

            # Plain `restic` on PATH, not just the auto-generated
            # `restic-cube` wrapper below (nixpkgs' services.restic module
            # own mechanism, `createWrapper`) -- that wrapper hardcodes a
            # single repository/password pair via env vars, which covers
            # the single-repo ad hoc commands (`restic-cube snapshots`,
            # `stats`, `check`) but not a `restic copy --repo B --from-repo
            # A` between two repositories, needed once
            # (`wiki/homelab/backup-runbook.md`'s migration step,
            # 2026-09-04, moving the repo to the `restic-backup` share
            # without losing what was already backed up to the old path).
            environment.systemPackages = [ pkgs.restic ];

            # sopsFile unset -- defaults to `config.sops.defaultSopsFile`
            # (secrets.yaml, set in nire/system/secrets/sops.nix, imported
            # by every Linux host via `system`). Declared HERE, not beside
            # the syncthing-*/forgejo-admin-password secrets in sops.nix,
            # same reasoning forgejo-admin-password's own declaration
            # gives: `backup` is cube-only, and a secret declared in
            # sops.nix decrypts on every `system` host (durandal/tenacity
            # included, neither backing up anything cube-shaped) --
            # declaring it here means it decrypts only where this module
            # is actually imported.
            #
            # owner/group/mode left at sops-nix's own defaults (uid 0, gid
            # 0, mode "0400" -- checked against the pinned sops-nix's
            # modules/sops/default.nix) rather than restated here the way
            # forgejo-admin-password overrides them: restic's own module
            # runs the backup as `user = "root"` (its default, not
            # overridden below), so root:root 0400 is already exactly
            # right, unlike Forgejo's secret which had to be readable by
            # the non-root `forgejo` user.
            #
            # THE VALUE ITSELF WAS NOT SET FROM THIS TREE, same shape as
            # restic-cube-password below: needs real decrypt access to
            # secrets.yaml, absent from the session that generated the
            # keypair. The private half sits at ~/.ssh/restic-cube-backup
            # on cube right now (mode 600, ed25519, no passphrase) --
            # setting this secret means reading that file's content into
            # sops from a session/host that has decrypt access, e.g.:
            #
            #     ssh nire-cube.local 'cat ~/.ssh/restic-cube-backup' \
            #         | jq -Rs . \
            #         | xargs -0 -I{} nix shell nixpkgs#sops nixpkgs#age \
            #             --command sops set \
            #             flake/modules/nire/system/secrets/secrets.yaml \
            #             '["restic-cube-ssh-key"]' {}
            #
            # (`jq -Rs .` JSON-encodes the multi-line key, escaping
            # newlines, into the single quoted scalar `sops set` expects
            # as its value argument.) Once set, `rm` the file on cube --
            # its only job was getting the value into secrets.yaml.
            sops.secrets.restic-cube-ssh-key = { };

            # See sops.secrets.restic-cube-ssh-key just above for why this
            # has no value from this tree yet either -- same gap, same fix
            # shape, first hit for this module 2026-08-28/29 (see the
            # module header's history section for the full build-time
            # failure this caused before it was found and fixed once).
            sops.secrets.restic-cube-password = { };

            services.restic.backups.cube = {
                repository    = sftpRepo;
                passwordFile  = config.sops.secrets.restic-cube-password.path;
                initialize    = true; # `restic cat config || restic init` in
                                      # preStart; the SFTP backend creates
                                      # the repo structure itself, but
                                      # needs sftpRepo's parent directory
                                      # to already exist (it does -- see
                                      # sftpRepo's own comment).

                # `nire@ts-hive`'s dedicated key, not whatever `ssh` would
                # otherwise pick (agent, default identity files) --
                # IdentitiesOnly=yes stops it from trying anything else
                # first. This is restic's own documented shape for a
                # non-default SFTP identity (nixpkgs' services.restic
                # module example uses the identical
                # `sftp.command='ssh ... -i ... -s sftp'` form).
                extraOptions = [
                    "sftp.command='${pkgs.openssh}/bin/ssh -i ${config.sops.secrets.restic-cube-ssh-key.path} -o IdentitiesOnly=yes nire@ts-hive -s sftp'"
                ];

                # The four paths issue #87's table names as unrecoverable,
                # plus the sqlite staging copies backupPrepareCommand below
                # produces. Deliberately NOT `/var/lib/prometheus2` (or
                # whichever path Prometheus's TSDB actually uses) --
                # issue #87's own open question 4: biggest path here,
                # least valuable, and fully regenerable by just scraping
                # again.
                paths = [
                    "/var/lib/forgejo"
                    "/var/lib/grafana"
                    "/var/lib/golink"
                    "/persist/secrets"
                    "/persist/passwords"
                    sqliteStagingDir
                ];

                # The three live db files above are excluded, not backed
                # up directly -- restic can capture a torn write off a
                # live sqlite db mid-transaction and store it without
                # complaint (issue #87's open question 1).
                # backupPrepareCommand below runs `sqlite3 <db> ".backup"`
                # into sqliteStagingDir first, so the *staged* copy (a
                # consistent snapshot as of the moment `.backup` ran) is
                # what actually gets backed up.
                exclude = builtins.attrValues sqliteDbs;

                backupPrepareCommand = ''
                    mkdir -p ${sqliteStagingDir}
                    ${lib.concatStringsSep "\n" (lib.mapAttrsToList
                        (name: db: "${pkgs.sqlite}/bin/sqlite3 ${db} \".backup '${sqliteStagingDir}/${name}.db'\"")
                        sqliteDbs)}
                '';

                # Starting point, not sized -- issue #87's open question 5
                # (`du` on cube's actual paths) was never run; nothing
                # here blocks re-tuning these once it is.
                pruneOpts = [
                    "--keep-daily 7"
                    "--keep-weekly 4"
                    "--keep-monthly 6"
                ];

                timerConfig = {
                    OnCalendar         = "03:30";
                    RandomizedDelaySec = "30m";
                    Persistent         = true;
                };
            };

            # No backup-persist.nix: cube has a plain persistent root
            # (cube-configuration.nix's header), not the `/root` wipe
            # durandal/tenacity get, so restic's own state (`/var/cache/
            # restic-backups-cube`, the systemd timer's last-run state)
            # survives reboots on its own. If a root-wiping host ever
            # imports this module, that state is disposable by design
            # (restic rebuilds its local cache from the repository) --
            # nothing to persist even then.

            # Anti-deletion (issue #87's open question 3: "push means cube
            # can delete its own backups") is NOT a Nix change, and
            # switching to SFTP didn't close it either -- `nire` can still
            # delete anything it has permission to on `restic-backup` over
            # SFTP, same as it could over NFS. Still needs a QNAP-side
            # native snapshot schedule on the `restic-backup` share itself
            # (moved here from `nire`'s `homes` share 2026-09-03
            # specifically so this snapshot schedule doesn't have to cover
            # every user's home directory to cover this repo), so cube can
            # write and prune within the restic repo but can't touch the
            # NAS's own snapshots. Cheapest rung of the ascending-effort
            # list #87 proposes; see the plan doc. Nothing in this module
            # enforces it, because nothing in this module *can* -- it's
            # QNAP admin-console configuration, same category of gap as the
            # two secret values above.
        };
}
