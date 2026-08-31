# restic: cube's only backup of its own service state, to the QNAP NAS
# already on the network. Added 2026-08-28 against issue #87 ("no backups
# anywhere in the fleet") and the plan at
# `claude cave/plans/2026-08-27-1816-cube-qnap-backup-plan.md` -- read that
# file for the reasoning this header only summarizes. Own category
# (`nire/homelab/backup/`), not `restic`: a category and its one module both
# named `restic` would declare `flake.modules.nixos.restic` twice and
# silently MERGE, the `containers`/`podman.nix` collision CLAUDE.md/AGENTS.md
# document -- same reason `git-forge` isn't `forgejo`.
#
# THE PLAN DOC'S "storage-NFS.nix IS DANGLING" CLAIM WAS WRONG, corrected
# while writing this module rather than left to rot: `nire/system/storage/`
# has no `dirsAsCategory.nix` of its own, so `storage-NFS.nix` is collected
# straight into the shared `system` aggregate (see
# `flake/modules/_lib/category-collector.nix`) -- which every Linux host
# imports. `nix eval .#nixosConfigurations.<host>.config.fileSystems` on all
# three (durandal, tenacity, cube) listed `/mnt/qnap-erin`, checked
# 2026-08-28 (the mount point was renamed to `/mnt/restic-backup`, a share
# dedicated to this module, shortly after -- storage-NFS.nix's own header
# has the current path; this comment's claim about it being collected
# through `system` rather than needing a new import is unaffected by the
# rename). So the QNAP NFS mount was ALREADY live everywhere, not an unused
# module one import away -- this module needed no new import to reach it,
# and neither does anything else that already imports `system`. Nothing in
# this repo has ever exercised that mount against the real QNAP, though:
# untested infra, not proven-working infra.
#
# REPOSITORY IS A LOCAL PATH ON THAT NFS MOUNT, NOT SFTP -- deliberately
# different from issue #87's original sketch. restic encrypts client-side
# regardless of backend, so a local-path repo on the mount gets the same
# encryption-at-rest #87 wanted from SFTP without standing up SSH/
# `rest-server`/Container Station on the QNAP. Trade-off, stated plainly
# because it's the one judgment call in this module rather than a fact:
# NFS export trust is IP-based, not keyed, so anything on the LAN with the
# right IP can mount the share. Compensated for below (see
# "anti-deletion"), not eliminated -- and less exposed than it was under
# the old shared `erin-pub` export, now that this lives on a share
# dedicated to backups rather than general QNAP storage.
#
# UPDATE 2026-08-28/29, REAL BUILD ON CUBE: rsynced this tree over ssh
# (darwin can't cross-build x86_64-linux -- AGENTS.md, Commands) to
# `nire-cube.local` and ran `just build` for real. First attempt failed --
# but at exactly the one predicted point, `sops.secrets.restic-cube-password`
# below having no value in the secrets.yaml this session had decrypt access
# to -- and that turned out to be a BUILD-time failure (sops-nix validates
# its manifest as part of `system.build.toplevel`, not only at activation),
# worse than the runtime failure this comment used to describe. What that
# first attempt didn't know: the secret DOES exist, set via `sops set`
# against a SEPARATE checkout on cube (`~/projects/nix/nixos-configs`, a
# few commits behind but with a real value) that this session hadn't
# checked -- not overwritten, just not looked at yet. Rebuilt with that
# checkout's `secrets.yaml` merged in: clean full-toplevel build, `restic`/
# `restic-cube`/`rustic`/`ssh-to-age` and the new `restic-backups-cube`
# service+timer all present in the diff, zero errors. `just modules`/
# `just lint` pass and the other hosts' toplevels are confirmed unaffected
# on top of that. Still open: the secret addition itself is uncommitted (in
# that other checkout, not this tree), no real `switch` has happened, the
# mount is still unconfirmed against the real QNAP, and -- per issue #87's
# own "done means" -- neither has a real restore of one Forgejo repo.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # `/mnt/restic-backup` (storage-NFS.nix), a QNAP share dedicated to
        # this module -- renamed 2026-08-28 from a generic `/mnt/qnap-erin`
        # shared with other, unrelated uses. `cube` underneath is a
        # host-scoped subdirectory, not stripped now that the share itself
        # is purpose-built: nothing stops another host getting its own
        # backup category later, and this keeps repositories from
        # colliding if one does.
        repoRoot          = "/mnt/restic-backup/cube";
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
            # THE VALUE ITSELF WAS NOT SET FROM THIS TREE. Adding it needs
            # real decrypt access to secrets.yaml (one of the age keys in
            # `.sops.yaml`: durandal, lysithea, tenacity, or cube's own
            # host key) -- absent from the session that originally wrote
            # this module (`sops -d` failed, no usable key found there).
            # It DOES exist now: set via `sops set` against a separate
            # checkout on cube itself (`~/projects/nix/nixos-configs`,
            # decrypt access via cube's own host key), confirmed 2026-08-29
            # by a full `just build` succeeding once that checkout's
            # `secrets.yaml` was in the tree being built -- restic-nix's own
            # header has the fuller account of both build attempts. Still
            # true: **that secrets.yaml edit is uncommitted**, sitting only
            # in that other checkout, not in this tree or on `experimental`
            # -- committing it (safe: it's ciphertext, this repo commits
            # `secrets.yaml` encrypted deliberately, see AGENTS.md Safety)
            # is a real remaining step, distinct from "the module works."
            # For the record, the command that would generate a fresh value
            # the same safe way (inline via command substitution, so it's
            # never a literal in the command text or in any tool output,
            # per `.claude/skills/secrets-hygiene/SKILL.md`) if this secret
            # ever needs rotating rather than just committing what already
            # exists:
            #
            #     nix shell nixpkgs#sops nixpkgs#age --command \
            #         sops set flake/modules/nire/system/secrets/secrets.yaml \
            #         '["restic-cube-password"]' \
            #         "\"$(openssl rand -base64 32)\""
            sops.secrets.restic-cube-password = { };

            services.restic.backups.cube = {
                repository    = repoRoot;
                passwordFile  = config.sops.secrets.restic-cube-password.path;
                initialize    = true; # `restic cat config || restic init` in
                                      # preStart; local backend creates
                                      # repoRoot itself if missing.

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

            # RequiresMountsFor, not a hand-written `after`/`wants` on the
            # mount unit: systemd resolves a plain path to whichever
            # unit(s) actually cover it, automount included -- covers
            # `/mnt/restic-backup` being an `x-systemd.automount` mount
            # (storage-NFS.nix) without this module needing to know or
            # hand-escape the generated unit name
            # (`mnt-restic\x2dbackup.mount`). `services.restic`'s own module
            # doesn't offer a hook for this, so it's added the same way
            # grafana.nix extends `before`/`wantedBy` on a unit
            # `services.grafana` itself defines -- additive on
            # `systemd.services."restic-backups-cube"`, not a
            # redeclaration.
            systemd.services."restic-backups-cube".unitConfig.RequiresMountsFor = repoRoot;

            # No backup-persist.nix: cube has a plain persistent root
            # (cube-configuration.nix's header), not the `/root` wipe
            # durandal/tenacity get, so restic's own state (`/var/cache/
            # restic-backups-cube`, the systemd timer's last-run state)
            # survives reboots on its own. If a root-wiping host ever
            # imports this module, that state is disposable by design
            # (restic rebuilds its local cache from the repository) --
            # nothing to persist even then.

            # Anti-deletion (issue #87's open question 3: "push means cube
            # can delete its own backups") is NOT a Nix change -- it's a
            # QNAP-side native snapshot schedule on the `restic-backup`
            # share, so cube can write and prune within the restic repo
            # but can't touch the NAS's own snapshots. Cheapest rung of
            # the ascending-effort list #87 proposes; see the plan doc.
            # Nothing in this module enforces it, because nothing in this
            # module *can* -- it's QNAP admin-console configuration, same
            # category of gap as the secret value above.
        };
}
