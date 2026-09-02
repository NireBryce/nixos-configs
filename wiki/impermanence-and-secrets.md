# Impermanence, initrd & secrets

## Contents

- [Impermanence](#impermanence)
- [Secrets](#secrets)

## Impermanence

**Read `flake/modules/nire/impermanence/root-rollback/WARN-impermanence.nix`
before changing anything near this, every time — no exceptions, per
[`../CLAUDE.md`](../CLAUDE.md)'s Safety section.** It's the module that
deletes the `/root` btrfs subvolume in initrd on every boot for the hosts
that import it.

- **Which hosts wipe `/root`** — `nire-durandal`, `nire-tenacity`
  do; `nire-cube` deliberately does not (real install turned out
  to be a plain root, not LUKS+impermanence). See
  [hosts.md](hosts.md) and [`../CLAUDE.md`](../CLAUDE.md)'s Safety section
  for the current, correctable-in-place list — don't assume "every host" or
  "no host" without checking the specific one.
- **Skill `impermanence-initrd`**
  (`.claude/skills/impermanence-initrd/SKILL.md`) — the sharp edges: `@name@`
  inside a stage-1 hook string is a live template placeholder even inside
  what looks like a comment, and the shell's own view of the machine
  (`lsblk`, `findmnt`, `/etc`) is scoped to its mount namespace and can
  describe a completely different, wrong-looking-but-correct disk layout —
  use `/proc/1/mountinfo`, `/dev/disk/by-uuid/`, `/run/current-system`
  instead.
- **[impermanence-stage1-migration.md](impermanence-stage1-migration.md)**
  — the move from scripted stage 1 to a systemd-initrd unit (done because
  nixpkgs flipped `boot.initrd.systemd.enable` to default true). Evaluates,
  was never booted before durandal/tenacity's first real boots confirmed the
  rollback works — see [history.md](history.md) for that confirmation.
- **Disk layout template** —
  [`../flake/doc/disko-impermanence-layout.md`](<../flake/doc/disko-impermanence-layout.md>),
  covered in more depth on [hosts.md](hosts.md).
- **New-host runbook** — [disk-formatting.md](disk-formatting.md): the
  ordered steps and safety warnings for actually getting a new host onto
  this layout, pulled together from the doc above, `WARN-impermanence.nix`,
  and the `new-host-config` skill.

## Secrets

- **sops-nix**, `flake/modules/nire/system/secrets/`. `secrets.yaml` is
  encrypted and committed in the repo on purpose.
- **`.sops.yaml`** enrolls `nire-durandal`, `nire-lysithea`, `nire-tenacity`,
  `nire-cube` — read the file directly for the current list rather than
  trusting a count here; [`../CLAUDE.md`](../CLAUDE.md)'s Safety section has
  been caught stale on this before. Enrolling a new host means converting its
  SSH host key with `ssh-to-age` and running `sops updatekeys secrets.yaml`.
  A host's SSH key can also drift out from under an existing enrollment (a
  reinstall, a regenerated host key) — found this way on `nire-lysithea`
  2026-08-29, where the enrolled key no longer matched
  `/etc/ssh/ssh_host_ed25519_key.pub`; re-run `host-age-key.sh` on the host
  in question and diff against `.sops.yaml` rather than assuming the
  original enrollment still holds.
- **Decrypting interactively on darwin needs `SOPS_AGE_KEY_FILE` set
  explicitly** — sops's default identity-file lookup differs by platform
  (Linux: `~/.config/sops/age/keys.txt`; darwin: `~/Library/Application
  Support/sops/age/keys.txt`), so a key placed at the Linux-XDG path is
  invisible to a plain `sops` invocation on macOS even with everything else
  correct. `secrets/sops-darwin.nix` (2026-08-29) sets it via
  `environment.variables`.
- **`SOPS_AGE_SSH_PRIVATE_KEY_FILE` can't be trusted for interactive use,
  even with a provably correct key** — chased on `nire-cube` 2026-08-29:
  pointing it at `/etc/ssh/ssh_host_ed25519_key` failed against every
  recipient, while converting to a native age identity and using
  `SOPS_AGE_KEY_FILE` decrypted cleanly with the same key — a real
  quirk in sops's SSH-conversion path, not this repo.
  `secrets/sops-interactive-key.nix` (2026-08-29) does the conversion every
  boot on every NixOS host — see
  [categories/system.md](categories/system.md)'s Secrets section for why
  unconditional regeneration matters under `/root` impermanence.
- **Not everything secret-shaped goes through sops.** On `nire-cube`:
  `elly`'s login password (`hashedPasswordFile`, `WARN-password-required.nix`)
  points at a file this repo never creates — a human must know the password
  anyway, so hand-creating it is the point. Grafana's `secret_key`
  ([monitoring](categories/monitoring.md)) started that way too, but a
  hand-created copy was found regressed (`root:root` ownership) on a live
  re-check 2026-08-24 with `grafana.service` crash-looping, so it's now
  generated and ownership-reasserted by `grafana-secret-key-setup.service`,
  declared by the module itself. Neither goes through sops: cube has no
  impermanence to lose the file to.
- **A full `nix flake check`/`just preflight` can fail with `error: path
  '<hash>-secrets.yaml' is not valid` in some eval environments** (seen in a
  sandboxed agent session, 2026-09-01, on a clean tree). `secrets/sops.nix`'s
  `secretsPath = ./secrets.yaml` carries string context; sops-nix's manifest
  validation calls `builtins.pathExists` on it first, forcing the store copy,
  which silently fails in that kind of session. Hits eval of any host
  importing `secrets/sops.nix` (all three NixOS hosts, via the shared
  `system` category). Doesn't affect a real `just build`/`switch` on the
  host, nor `just modules`/`just lint`. Not a bug in this repo.
