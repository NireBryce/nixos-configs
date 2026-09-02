# New host disk formatting (LUKS + btrfs + impermanence)

## Contents

- [What this is for](#what-this-is-for)
- [Decide before touching a disk](#decide-before-touching-a-disk)
- [Wiring the layout in](#wiring-the-layout-in)
- [Actually formatting the disk](#actually-formatting-the-disk)
- [What depends on this having actually run](#what-depends-on-this-having-actually-run)
- [Confirming the rollback actually works](#confirming-the-rollback-actually-works)
- [Traps](#traps)
- [See also](#see-also)

The runbook-shaped piece of adding a new host: **the actual disk step**, not
the Nix config around it. Skill `new-host-config` covers the whole
host-adding decision tree; [flake/doc/disko-impermanence-layout.md](<../flake/doc/disko-impermanence-layout.md>)
covers the generator's own mechanism in full. This page is the order of
operations and the safety warnings that are otherwise scattered across both
— read this once before doing it, not instead of either.

**This is the destructive step.** `disko` partitions a real disk. Read
[`../CLAUDE.md`](../CLAUDE.md)'s Safety section before running any of this
against real hardware, and see the placeholder-device rule below before
touching a device path at all.

## What this is for

For a **new** host that will wipe `/root` on every boot — durandal and
tenacity's shape, not `nire-cube`'s. Impermanence is a per-host decision, not
a default: see [categories/impermanence.md](categories/impermanence.md) for
which hosts currently import it, and the `new-host-config` skill's "Impermanence
or not?" section for how that decision gets made for a host that doesn't
exist yet. If the new host is opting *out* the way `nire-cube` and the
handhelds do, none of this page applies — say so in the host's own header
instead, the way `cube-configuration.nix` does.

`nire/impermanence/_disko/impermanence-luks-btrfs.nix` reproduces durandal
and tenacity's hand-run layout as a reusable generator: one LUKS-encrypted
partition, btrfs inside it, subvolumes for `root`/`home`/`nix`/`persist`/`log`,
and an unmounted `root-blank` subvolume. **Nothing in this repo currently
calls it** — every live host either has hand-written `hardware-*.nix` from a
real install, or (cube) never adopted this layout at all. The disko doc's own
inline example is the only reference until a new host actually uses it.

## Decide before touching a disk

Per the disko doc and the `new-host-config` skill, in order:

1. **The real device path**, found on the target machine (`lsblk`,
   `ls /dev/disk/by-id/`) — not guessed from another host's layout.
2. **`includeSecureboot`** (default off) — durandal's own addition
   (`/var/lib/sbctl`), not universal. Decide for this host explicitly.
3. **`swapSize`** (default `null`, no swap) — tenacity has none; durandal's
   shape is the one with swap. Decide for this host explicitly, don't
   silently inherit either default.
4. **LUKS unlock method** — the generator sets none of `keyFile` /
   `passwordFile` / `enrollFido2`, so disko's own default applies:
   interactive passphrase, at partition time and at every later boot. That's
   what durandal and tenacity actually do. Automating it (key file on
   removable media, TPM/FIDO2 enrollment) is a real per-host decision the
   template deliberately doesn't make for you.

## Wiring the layout in

Call the generator curried with this host's own parameters, in its
`imports` list — the disko doc's own example:

```nix
imports = [
    (import ../../nire/impermanence/_disko/impermanence-luks-btrfs.nix {
        device = "/dev/disk/by-id/REPLACE-ME-before-running-disko";
    })
];
```

Two things easy to get backwards here:

- **The placeholder device path must be unmistakably fake.** Never a
  plausible-looking one like `/dev/nvme0n1` — that path exists on a real
  machine in this repo already (tenacity), and a plausible guess run through
  disko's actual partitioning step on the wrong box silently wipes a disk
  that has real data on it. A path that doesn't exist just fails loudly,
  which is the point. Replace it with the real `/dev/disk/by-id/...` path
  only once you're certain which physical disk on which physical machine
  you're pointed at.
- **This generator produces the disk layout only.** It does not add the
  `impermanence` category import, which is what actually brings in
  `WARN-impermanence.nix` (the rollback unit), the hibernation guards, and
  `environment.persistence`. Both have to happen — the disk layout and the
  category import are two separate steps in the host's own config, not one.

## Actually formatting the disk

This repo does not currently carry a live install/bootstrap runbook of its
own — the earlier live-USB installer mechanism (`nire-installer`, embedded
flake, unattended `nixos-install`) was removed 2026-08-27; see
[history.md](history.md). What follows is disko's own standard interface,
not something this repo has run end to end and confirmed — the generator
itself is evaluation-verified only (see the doc's own "What was actually
verified" section), never against real hardware.

1. Boot install media on the target machine.
2. `git clone` this repo (or otherwise get the flake onto the install media)
   with the new host's config, including the wired-in generator above,
   already committed — `git add` first, since flakes in a git repo ignore
   untracked files.
3. Run disko in `disko` mode against the real device, pointed at this host's
   own `nixosConfigurations` entry — disko's own documented invocation
   shape, not a command this repo has its own wrapper for.
4. Once partitioned and mounted, install normally (`nixos-install` or
   equivalent) against the flake.

## What depends on this having actually run

**A host can be fully wired up in this repo's Nix config and still be
unable to boot**, because `WARN-impermanence.nix`'s rollback unit depends on
the `root-blank` subvolume existing at the btrfs top level — and that
subvolume is only created once disko has actually been run against the real
disk. Evaluating cleanly, or even building a toplevel, proves nothing about
this; it's runtime state that doesn't exist until the disk step above has
happened. Say so explicitly in the new host's own header if it's been wired
in before the disk step has run, the way `nire-lego`'s did before its
removal (git history) and `cube-configuration.nix` does for the unrelated,
opposite case (no impermanence at all).

First boot also needs the KDE half of the hibernation guard —
`root-rollback/kde-sleepmode.nix` sets `SleepMode=1` in `powerdevil.rc`,
required to match `WARN-impermanence.nix`'s `nohibernate` kernel parameter or
suspend breaks outright. It's `homeManager`-class and reaches every desktop
host through `ellyHomeManager` automatically — nothing extra to wire in for
this specifically, just worth knowing it's there if suspend misbehaves on
first boot.

## Confirming the rollback actually works

The machine coming up proves nothing — a failed rollback that silently
doesn't wipe anything looks exactly like a working system until the disk
fills. The confirmation method used on tenacity
([impermanence-stage1-migration.md](impermanence-stage1-migration.md)):
compare the `/root` subvolid across a reboot, not just check that boot
succeeded.

```sh
findmnt -no SOURCE /        # or: awk '$5=="/"{print $NF}' /proc/1/mountinfo
journalctl -b 0 -u restore-root
```

The subvolid must change on every boot — on tenacity it moved 607 → 622 →
627 across successive boots, against neighbouring subvolumes sitting at
257–265 (a `/root` subvolid far above its siblings is the rollback
demonstrably running, not just present). `CLAUDE.md`'s State table records
each host's confirmation this same way — "confirmed by subvolid in the
journal, not by the machine coming up" — update it for the new host once
this has actually been checked, not once the machine merely boots.

## Traps

- **`@name@` inside a stage-1 hook string is a live template placeholder,
  even inside what reads like a comment** — naming one in a comment can
  paste a whole other script in and execute most of it. Full mechanism:
  skill `impermanence-initrd`.
- **The shell's own view of the machine can be scoped wrong.** `lsblk`,
  `findmnt`, `/etc` are scoped to the running shell's mount namespace and
  can describe a completely different, wrong-looking-but-correct disk
  layout. Use `/proc/1/mountinfo`, `/dev/disk/by-uuid/`, and
  `/run/current-system` instead — same skill.
- **Hibernation must actually be disabled, not just assumed absent.**
  `systemd-gpt-auto-generator` can activate a swap partition and wire up
  `/sys/power/resume` on its own, with no `resume=` on the kernel command
  line and no `swapDevices` entry in the config — checking the config for a
  resume device proves nothing about whether the running machine has one.
  `WARN-impermanence.nix`'s own history section has the full account of how
  this was gotten wrong here once already.
- **A `just check`/toplevel build proves the config evaluates, not that the
  disk is formatted or the rollback runs.** Both are runtime facts; see the
  two sections above.

## See also

- [flake/doc/disko-impermanence-layout.md](<../flake/doc/disko-impermanence-layout.md>)
  — the generator itself: what it produces, what it deliberately leaves out,
  and exactly how it was verified (and how it wasn't).
- `WARN-impermanence.nix`
  (`flake/modules/nire/impermanence/root-rollback/WARN-impermanence.nix`) —
  the rollback module this disk layout exists to support; read before
  changing anything near it, every time.
- Skill `new-host-config` (`.claude/skills/new-host-config/SKILL.md`) — the
  full host-adding decision tree this page is one piece of.
- Skill `impermanence-initrd`
  (`.claude/skills/impermanence-initrd/SKILL.md`) — the initrd-specific sharp
  edges referenced above.
- [categories/impermanence.md](categories/impermanence.md) — what's in the
  category, which hosts import it today.
- [impermanence-and-secrets.md](impermanence-and-secrets.md) — the
  cross-cutting topic page (impermanence and secrets together).
- [impermanence-stage1-migration.md](impermanence-stage1-migration.md)
  — the systemd stage-1 migration this mechanism runs on now, and the
  subvolid verification method in full.
- [hosts.md](hosts.md) — current roster and per-host boot/switch status.
