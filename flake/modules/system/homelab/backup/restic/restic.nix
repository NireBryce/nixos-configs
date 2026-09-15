# restic: cube's only backup of its own service state, to the QNAP NAS
# already on the network. Added 2026-08-28 against issue #87 ("no backups
# anywhere in the fleet"), which is closed: a real restore drill on
# 2026-09-06 opened a genuine, complete Forgejo database out of the repo.
# Own category (`system/homelab/backup/`), not `restic`: a category and its
# one module both named `restic` would declare `flake.modules.nixos.restic`
# twice and silently MERGE, the `containers`/`podman.nix` collision
# AGENTS.md documents -- same reason `git-forge` isn't `forgejo`.
#
# Kept in the wiki, not restated here: what is verified and what isn't,
# wiki/categories/backup.md; how each one-time setup step actually went,
# `backup-history.md`; the commands for restoring, migrating, or re-setting
# a secret, wiki/homelab/backup-runbook.md. Traps sit next to the options.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # `restic-backup`, the QNAP's own dedicated share (Storage Pool 2),
        # not `nire`'s home: QNAP snapshots are per-shared-folder, and the
        # anti-deletion mitigation below would otherwise have to snapshot
        # every user's home directory to cover this one repo. `cube`
        # underneath it is a host-scoped subdirectory -- nothing stops
        # another host getting its own backup category later, and this
        # keeps repositories from colliding if one does.
        #
        # Live since 2026-09-05, history and all: cube switched onto this
        # path and the five snapshots from the old
        # `/share/homes/nire/restic-cube` were migrated in with `restic
        # copy`. A NEW path here needs its parent directory to exist and be
        # writable by `nire` first -- restic's SFTP backend creates the
        # repository structure on `init` but not the directory above it.
        sftpRepo          = "sftp:nire@ts-hive:/share/restic-backup/cube";

        # MUST NOT LIVE UNDER `/var/cache/restic-backups-cube`, which is
        # `RESTIC_CACHE_DIR` (nixpkgs' restic module sets it to
        # `/var/cache/restic-backups-${name}`, matching `CacheDirectory=`).
        # restic silently refuses to back up its own cache directory -- no
        # error, no log line, the files just aren't in the snapshot. This
        # staging directory was nested there from the module's creation
        # until 2026-09-06, so the sqlite consistency mechanism #87 asked
        # for never actually ran: `backupPrepareCommand` wrote real files
        # and restic dropped every one. `/var/lib` is a sibling of nothing
        # restic claims. Root-caused by A/B on `--dry-run` file counts
        # (603 vs 600, the one difference being the cache dir) -- full
        # account in backup.md.
        sqliteStagingDir  = "/var/lib/restic-backups-cube-sqlite-staging";

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

            # Plain `restic` as well as the `restic-cube` wrapper nixpkgs
            # generates: that wrapper hardcodes ONE repository/password
            # pair via env vars, which covers `restic-cube snapshots`/
            # `stats`/`check` but not a two-repository `restic copy --repo
            # B --from-repo A` -- needed for the 2026-09-04 migration, and
            # for any future one (backup-runbook.md).
            environment.systemPackages = [ pkgs.restic ];

            # sopsFile unset -- defaults to `config.sops.defaultSopsFile`
            # (secrets.yaml, set in system/system/secrets/sops.nix, imported
            # by every Linux host via `system`). Declared HERE and not in
            # sops.nix, same reasoning forgejo-admin-password's own
            # declaration in forgejo.nix gives: `backup` is cube-only, and
            # a secret declared in sops.nix decrypts on every `system`
            # host (durandal/tenacity included, neither backing up
            # anything cube-shaped) -- declaring it here means it decrypts
            # only where this module is actually imported.
            #
            # owner/group/mode left at sops-nix's defaults (root:root
            # 0400, checked against the pinned sops-nix) rather than
            # overridden the way forgejo-admin-password's are: restic's
            # module runs the backup as root, so the defaults are already
            # right. A non-root service is what forces an override.
            #
            # Both values were set 2026-08-30/31 and real timer runs have
            # succeeded on them since. A secret declared here with NO value
            # in secrets.yaml fails at BUILD time, not runtime -- sops-nix
            # validates its manifest as part of `system.build.toplevel`,
            # which is how this first bit 2026-08-28/29 (history below).
            # Re-setting one means `sops set` from a session that has
            # decrypt access; backup-runbook.md has the exact incantation,
            # including the `jq -Rs .` that JSON-encodes a multi-line key.
            sops.secrets.restic-cube-ssh-key  = { };
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

                # `prepare.log` started as a diagnostic 2026-09-06 and is
                # kept as a permanent sanity check: it is what proved this
                # step was writing real files while restic dropped them.
                # It sits under the EXCLUDED cache directory on purpose --
                # meant to be read locally, never backed up. Full store
                # paths for every command, not bare names: this script runs
                # with no useful `$PATH`, and ad hoc reproductions of it
                # kept hitting `command not found`.
                backupPrepareCommand = ''
                    {
                        ${pkgs.coreutils}/bin/echo "=== prepare run: $(${pkgs.coreutils}/bin/date -Iseconds) ==="
                        ${pkgs.coreutils}/bin/mkdir -p ${sqliteStagingDir}
                        ${lib.concatStringsSep "\n" (lib.mapAttrsToList
                            (name: db: ''
                                ${pkgs.sqlite}/bin/sqlite3 ${db} ".backup '${sqliteStagingDir}/${name}.db'"
                                ${pkgs.coreutils}/bin/echo "${name}.db: $(${pkgs.coreutils}/bin/stat -c%s ${sqliteStagingDir}/${name}.db 2>&1 || ${pkgs.coreutils}/bin/echo MISSING) bytes"
                            '')
                            sqliteDbs)}
                    } >> /var/cache/restic-backups-cube/prepare.log 2>&1
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

            # Anti-deletion is NOT a Nix change and SFTP didn't close it:
            # `nire` can delete anything it has permission to on
            # `restic-backup`, same as it could over NFS. What guards the
            # repo is a QNAP-side native snapshot schedule on that share --
            # daily 04:30, keeping 5 days, confirmed live 2026-09-05 -- so
            # cube can write and prune inside the repository but cannot
            # touch the NAS's own snapshots. Nothing here enforces that,
            # because nothing here *can*: it is admin-console
            # configuration, and only the wiki records whether it is still
            # true (backup.md).
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-28 to 2026-08-31, THE NFS ERA — the repository was a local path on
# the QNAP's NFS mount, not SFTP. Deliberate at the time: restic encrypts
# client-side regardless of backend, so a local-path repo gets encryption at
# rest without standing up SSH on the QNAP. The stated trade-off -- NFS
# export trust is IP-based, not keyed -- is what ended up mattering: a real
# switch on cube hit `mount.nfs: access denied by server`, and the QNAP admin
# console has no menu for forcing key-only SSH, so the weaker option was also
# the broken one. SFTP with a dedicated key replaced it 2026-08-31, which is
# what issue #87 had originally suggested. `storage-NFS.nix` still exists and
# is still imported by every Linux host -- nothing else stopped using it.
#
# Two corrections from that era worth not re-making: the plan doc claimed
# `storage-NFS.nix` was dangling, and it was not (no `dirsAsCategory.nix` in
# `system/system/storage/`, so it collects straight into the shared `system`
# aggregate -- checked by evaluating `config.fileSystems` on all three Linux
# hosts); and a build failed on `sops.secrets.restic-cube-password` having no
# value, at BUILD time rather than runtime, because a second checkout on cube
# held the only secrets.yaml that had it.
#
# 2026-09-03 to 2026-09-06 — the repo moved off `nire`'s home to the
# `restic-backup` share, cube switched onto it, the old path's five snapshots
# were migrated in with `restic copy`, and the sqlite staging bug above was
# found and fixed. Issue #87 closed on the restore drill that followed. The
# step-by-step account of all of it, including which parts took three tries,
# is wiki/categories/backup-history.md.
