# rustic — an interactive alternative to the plain `restic` CLI

## Contents

- [What it is](#what-it-is)
- [Getting it](#getting-it)
- [Pointing it at this repo's repository](#pointing-it-at-this-repos-repository)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

[rustic](https://github.com/rustic-rs/rustic) (the `rustic-rs` project, not
the unrelated `bnavetta/rustic` "restic wrapper" that shares its name in
search results) — a client tool for the repository
[backup](../categories/backup.md) writes, not a service this fleet runs.
Installed 2026-08-28 in
`nirePackages/shell-apps/backup-tools/rustic.nix`, so it's on every host
`ellyHomeManager` reaches.

## What it is

A full reimplementation of restic in Rust, not a wrapper around the `restic`
binary — it reads and writes the **same repository format** restic does, so
it can operate on the same repository [backup](../categories/backup.md)
writes directly, no conversion, no separate copy. Since version 0.8.0 it
ships an interactive TUI:

```sh
rustic snapshots -i
```

opens a snapshots view (browse, forget, retag) and a tree view (file
preview, diffs, restore a whole snapshot / a subtree / a single file) — one
session covering most of what [the runbook](backup-runbook.md)'s manual
`snapshots`/`restore` commands do by hand. `check` and `prune` stay outside
the TUI, which is fine — those are already the module's job
(`runCheck`/`pruneOpts` on a timer), not something to run interactively.

The project's own FAQ states rustic and restic can share a repository, with
one caveat: don't run `prune` from both at the same time.

## Getting it

**Installed, 2026-08-28**: `pkgs.rustic` (pname `rustic`, v0.11.3,
`mainProgram = "rustic"`) via
`nirePackages/shell-apps/backup-tools/rustic.nix` — a plain `home.packages`
entry, no `programs.*`/`services.*` module exists for it. It's in
`ellyHomeManager`, which every host shares, rather than gated to cube: it's
a generally useful restic-repository browser, not tied to this one
repository, and `just available rustic` found no Homebrew cask duplicating
it (so no `isDarwin` judgment call the way `obsidian.nix` needed one).

**Build- and run-verified on cube, 2026-08-29**: a real `just build` on
cube (synced over ssh — darwin can't cross-build `x86_64-linux`) produced a
clean `home-manager-generation` with `rustic` in it, and running the built
binary directly —

```
$ /nix/store/44nmllvciygc0rxcgbf90v62djx1fqa0-rustic-0.11.3/bin/rustic --version
rustic 0.11.3
```

— confirms it actually executes on the real hardware, not just that Nix
says it should. **Switched, 2026-08-30**: `which rustic` now resolves under
`/etc/profiles/per-user/elly/bin/` on cube, so it's on `elly`'s real
interactive `$PATH` there, not just built. Still true on darwin: only
`nix eval`-level confirmation (present in `home.packages`, absent from the
unsupported-package drop list), no build, run, or switch there yet.

Try it without a switch on a host that hasn't gotten there yet:

```sh
nix shell nixpkgs#rustic
# or, one-off:
nix run nixpkgs#rustic -- snapshots -i
```

## Pointing it at this repo's repository

**The repository moved, 2026-08-31**: SFTP now, not a local path on an NFS
mount — see [backup](../categories/backup.md) for why. The command below is
updated to match but is **more speculative than the rest of this page**:
it's unconfirmed whether rustic accepts the same `-o sftp.command=` shape
restic's `extraOptions` does for pointing at a non-default SSH identity —
nothing has tried.

**Name mismatch to know about regardless**: rustic's own environment
variables are `RUSTIC_REPOSITORY` / `RUSTIC_PASSWORD_FILE`, not restic's
`RESTIC_REPOSITORY` / `RESTIC_PASSWORD_FILE` — so it will **not**
automatically pick up the environment the module's generated `restic-cube`
wrapper script sets (see the runbook's "Ad hoc restic commands" section).
Either export the `RUSTIC_*` names yourself or pass the equivalent flags
directly:

```sh
sudo rustic -r sftp:nire@ts-hive:/share/restic-backup/cube \
    --password-file /run/secrets/restic-cube-password \
    -o sftp.command="ssh -i /run/secrets/restic-cube-ssh-key -o IdentitiesOnly=yes nire@ts-hive -s sftp" \
    snapshots -i
```

`sudo` for the same reason plain `restic-cube` needs it: both secret files
are root-owned, mode `0400`, by sops-nix's own default — see the runbook.

## What's verified here

**On cube**: builds (2026-08-29), switched and on `elly`'s real `$PATH`
(2026-08-30), and the binary runs (`rustic --version` → `rustic 0.11.3`).
**On darwin**: `nix eval` only — present in `home.packages`, survives the
platform filter, never built, run, or switched there.

**Still entirely unverified everywhere**: whether the TUI actually behaves
as its own docs describe, and whether the command shape in "Pointing it at
this repo's repository" above is right — pointing it at the real
repository specifically can't be tested yet regardless, since neither sops
secret the backup itself needs has a value in this tree yet (see
[the runbook](backup-runbook.md)). All of "What it is" and that section are
transcribed from rustic's
own GitHub repo, docs site, and FAQ, not from a run here; `--version` is
the only subcommand actually invoked. Treat the rest the way
[forgejo.md](forgejo.md) treats its own untested commands: plausible from
the source, not proven.

## See also

- [Backup runbook](backup-runbook.md) — the plain-`restic` commands this
  page is an alternative front end for, and the wrapper-script env vars
  that don't carry over automatically.
- [backup](../categories/backup.md) — the module that actually writes this
  repository.
- [rustic-rs/rustic](https://github.com/rustic-rs/rustic) and
  [rustic.cli.rs](https://rustic.cli.rs/) — the live, canonical source;
  right about the current build even when this page has drifted.
- Skill `nirepackages-platform-support` — the process the package addition
  followed (platform check, Homebrew-duplicate check).
