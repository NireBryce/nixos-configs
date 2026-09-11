# New host disk formatting, for agents

_Last modified: 2026-09-11_

Condensed from [disk-formatting.md](disk-formatting.md), which keeps the
reasoning and the full warnings. Facts only here.

**Destructive.** `disko` partitions a real disk. Read `CLAUDE.md`'s Safety
section first. Skill `new-host-config` is the surrounding decision tree.

## Scope

Only for a new host that will wipe `/root` on every boot — durandal and
tenacity's shape. A host opting out (cube, the handhelds) uses none of this.

`nire/impermanence/_disko/impermanence-luks-btrfs.nix`: one LUKS partition,
btrfs inside, subvolumes `root`/`home`/`nix`/`persist`/`log`, plus an
unmounted `root-blank`. **Nothing in this repo calls it today** — every live
host has hand-written `hardware-*.nix` from a real install, or (cube) never
adopted the layout. Evaluation-verified only, never run against hardware.

## Decide explicitly, four things

1. **Real device path**, read on the target machine (`lsblk`,
   `ls /dev/disk/by-id/`). Never inferred from another host.
2. **`includeSecureboot`** — default off; durandal's addition
   (`/var/lib/sbctl`), not universal.
3. **`swapSize`** — default `null`; tenacity has none, durandal does.
4. **LUKS unlock** — the generator sets no `keyFile`/`passwordFile`/
   `enrollFido2`, so disko's default applies: interactive passphrase at
   partition time and every boot.

## Wiring it in

```nix
imports = [
    (import ../../nire/impermanence/_disko/impermanence-luks-btrfs.nix {
        device = "/dev/disk/by-id/REPLACE-ME-before-running-disko";
    })
];
```

- **The placeholder must be unmistakably fake.** Never a plausible path like
  `/dev/nvme0n1` — that exists on tenacity, and disko pointed at the wrong
  box silently wipes real data.
- **This is the disk layout only.** The `impermanence` category import
  (`WARN-impermanence.nix`, hibernation guards, `environment.persistence`)
  is a separate step. Both are required.

## Formatting

No live install runbook in this repo — the `nire-installer` mechanism was
removed 2026-08-27. Standard disko interface:

1. Boot install media.
2. Get the flake onto it with the new host committed — **`git add` first**,
   flakes ignore untracked files.
3. Run disko in `disko` mode against the real device, pointed at the host's
   `nixosConfigurations` entry.
4. `nixos-install` against the flake.

## Runtime facts eval cannot prove

- **A host can be fully wired and still unbootable.** The rollback needs the
  `root-blank` subvolume at the btrfs top level, which only exists once disko
  has run. Note it in the host's header if wired before the disk step.
- **First boot needs the KDE hibernation half** —
  `root-rollback/kde-sleepmode.nix` sets `SleepMode=1` in `powerdevil.rc`,
  matching the `nohibernate` kernel parameter, or suspend breaks outright.
  `homeManager`-class, arrives via `ellyHomeManager`.

## Confirming the rollback runs

The machine booting proves nothing. Compare `/root`'s **subvolid across a
reboot**:

```sh
findmnt -no SOURCE /        # or: awk '$5=="/"{print $NF}' /proc/1/mountinfo
journalctl -b 0 -u restore-root
```

It must change every boot. On tenacity: 607 → 622 → 627, against
neighbouring subvolumes at 257–265. Record it that way, not "the machine
came up".

## Traps

- **The shell's view of the machine can be scoped wrong** — `lsblk`,
  `findmnt`, `/etc` are mount-namespace-scoped and can describe a different,
  wrong-looking-but-correct layout. Use `/proc/1/mountinfo`,
  `/dev/disk/by-uuid/`, `/run/current-system`.
- **Hibernation must be verified disabled, not assumed.**
  `systemd-gpt-auto-generator` can activate a swap partition and wire
  `/sys/power/resume` with no `resume=` on the cmdline and no `swapDevices`
  entry. Checking the config proves nothing about the running machine.

## See also

[disk-formatting.md](disk-formatting.md) ·
[flake/doc/disko-impermanence-layout.md](<../flake/doc/disko-impermanence-layout.md>)
· skill `impermanence-initrd` ·
[categories/impermanence.md](categories/impermanence.md)
