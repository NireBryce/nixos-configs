# Impermanence, initrd & secrets

## Impermanence

**Read `flake/modules/nire/impermanence/WARN-impermanence.nix` before
changing anything near this, every time — no exceptions, per
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
- **[`../claude cave/lessons-learned-impermanence-stage1-migration.md`](<../claude cave/lessons-learned-impermanence-stage1-migration.md>)**
  — the move from scripted stage 1 to a systemd-initrd unit (done because
  nixpkgs flipped `boot.initrd.systemd.enable` to default true). Evaluates,
  was never booted before durandal/tenacity's first real boots confirmed the
  rollback works — see [history.md](history.md) for that confirmation.
- **Disk layout template** —
  [`../flake/doc/disko-impermanence-layout.md`](<../flake/doc/disko-impermanence-layout.md>),
  covered in more depth on [hosts.md](hosts.md).

## Secrets

- **sops-nix**, `flake/modules/nire/system/secrets/`. `secrets.yaml` is
  encrypted and committed in the repo on purpose.
- **`.sops.yaml`** enrolls `nire-durandal`, `nire-lysithea`, `nire-tenacity`,
  `nire-cube` — read the file directly for the current list rather than
  trusting a count here; [`../CLAUDE.md`](../CLAUDE.md)'s Safety section has
  been caught stale on this before. Enrolling a new host means converting its
  SSH host key with `ssh-to-age` and running `sops updatekeys secrets.yaml`.
- **Not everything secret-shaped goes through sops.** Two things on
  `nire-cube` deliberately don't, though they've diverged in how they're
  provisioned: `elly`'s login password (`hashedPasswordFile`,
  `WARN-password-required.nix`) still points at a file this repo never
  creates, expected to exist by hand at a fixed path under `/persist` — a
  human has to know the password anyway, so hand-creating it is the point,
  not a gap. Grafana's `secret_key`
  ([monitoring](categories/monitoring.md)) started the same way, but a
  hand-created copy of it was found regressed (ownership reverted to
  `root:root`) on a live re-check 2026-08-24 with nobody noticing until
  `grafana.service` was already crash-looping — so as of that date it's
  generated and its ownership reasserted by a `grafana-secret-key-setup.service`
  the module itself declares, not by hand. Neither goes through sops
  either way — same reasoning for both: cube has no impermanence to lose
  the file to, so there's nothing sops's own persistence story would buy
  that a plain file under `/persist` doesn't already have.
