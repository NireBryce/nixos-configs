# Impermanence on systemd stage 1 — what is known

## Contents

- [Why it moved](#why-it-moved)
- [The unit](#the-unit)
- [What the move cost, and what replaced it](#what-the-move-cost-and-what-replaced-it)
- [Things that are true of this machine and were not obvious](#things-that-are-true-of-this-machine-and-were-not-obvious)
- [How to tell the unit is really there](#how-to-tell-the-unit-is-really-there)
- [And that it ran](#and-that-it-ran)
- [Related](#related)

> **Written by Claude Code.** A record of how the `/root` rollback works here
> and what was learned getting it there, not a procedure. The migration is done.

`WARN-impermanence.nix` deletes the `/root` btrfs subvolume on every boot and
re-creates it from a `root-blank` snapshot. Both hosts import it through the
`impermanence` category -- named `boot` until 2026-08-11, when it was renamed
because `boot` had come to mean only this, and read as though it covered
bootloader concerns it never touched.

It ran from `boot.initrd.postResumeCommands` — scripted stage 1 — until
2026-08-10, and now runs as `boot.initrd.systemd.services.restore-root`.
Both hosts have booted on it (tenacity since generation 62, durandal since
generation 222), with each rollback confirmed by subvolid in the journal
rather than by the machine merely coming up.

---

## Why it moved

Not a preference. The 2026-08-07 nixpkgs flipped `boot.initrd.systemd.enable`
to default `true` and warns that scripted initrd is "deprecated and scheduled
for removal in 26.11" — the release that same bump moved both hosts onto.
Updating the lock broke evaluation of both hosts at once:

```
systemd stage 1 does not support `boot.initrd.postResumeCommands`
```

The two mechanisms cannot coexist, so the switch had to be atomic. Reverting
means restoring `postResumeCommands` **and** pinning
`boot.initrd.systemd.enable = false`, together.

`boot.initrd.systemd.enable` is not `boot.loader.systemd-boot`, which both hosts
also set. That is the EFI bootloader; this is systemd inside the initramfs.
Similar names, unrelated options — and the likeliest reason the first attempt at
this looked finished when it was not.

## The unit

```nix
wantedBy = [ "initrd.target" ];
requires = luksDeviceUnits;                                    # dev-mapper-enc.device
after    = [ "initrd-root-device.target" ] ++ luksDeviceUnits ++ luksCryptUnits;
before   = [ "sysroot.mount" ];
unitConfig.DefaultDependencies = "no";
serviceConfig.Type = "oneshot";
```

`initrd-root-device.target` is the host-generic synchronisation point: reached
once the root block device exists, after LUKS unlock, whatever the volume is
called.

The LUKS unit names are derived, not written out. systemd names the crypt unit
after the **volume**, not the host: nixpkgs writes
`boot.initrd.luks.devices.<n>` as field 1 of the initrd crypttab
(`luksroot.nix`, `stage1Crypttab`) and `systemd-cryptsetup-generator` derives
`systemd-cryptsetup@<that field>.service` from it. Both machines use `enc`.

`Requires=` and `After=` are independent — activation dependency versus pure
ordering — and systemd.unit(5) says to pair them. `Requires=` alone can run
before the device exists; `After=` alone runs the service and lets it fail.

## What the move cost, and what replaced it

**Ordering against udev, gained.** The scripted version mounted
`fileSystems."/".device`, a `/dev/disk/by-uuid` path on both hosts, with no
`udevadm settle` between the LUKS open and the rollback — the next settle in
`stage-1-init.sh` ran after the whole block. It raced udev, and losing meant a
failed mount and a wipe that silently did not happen. Ordering `After=` the
device units makes udev's completion a precondition, so no polling is involved.

**Loud failure, gained.** There is no `set -e` in `stage-1-init.sh`, so after a
failed mount every later command failed harmlessly against an empty `/mnt`.
systemd job scripts are built by `makeJobScript`, which is `writeShellScriptBin`
over `set -e`, so the first failure aborts the unit — and
`OnFailure = emergency.target` stops the boot rather than continuing with
`/root` un-wiped.

**Hibernation safety, lost — and not restored by the obvious guard.**
`postResumeCommands` ran *after* the kernel's resume attempt, so a successful
hibernation resume skipped the wipe. The safety was in the option's name. A
plain `initrd.target` unit has no equivalent and can race ahead of the resume,
deleting the `/root` the restored image expects.

The obvious replacement, `unitConfig.ConditionKernelCommandLine = [ "!resume" ]`,
**cannot fire**. systemd does not need `resume=` on the kernel command line:
`systemd-gpt-auto-generator` finds the swap partition by GPT type UUID and sets
`/sys/power/resume` itself. On tenacity it had already done so — 259:6, with
nothing on the command line.

It is closed by `boot.kernelParams = [ "nohibernate" ]` instead, which removes
the hazard rather than testing for it. After that, `/sys/power/state` no longer
offers `disk` and `/sys/power/resume` reads `0:0`. The condition stays as a
second line only.

## Things that are true of this machine and were not obvious

- **Swap exists that nothing configured.** `swapDevices = [ ]` and
  `boot.resumeDevice = ""` on both hosts, yet tenacity runs 20G of swap on
  `nvme0n1p6`, activated by `systemd-gpt-auto-generator` as
  `dev-disk-by\x2ddesignator-swap.swap`. Reading the config would tell you the
  opposite.
- **Hibernation was happening for months.** KDE asked for hybrid-sleep — suspend
  *plus* writing a hibernation image — and `systemd-hybrid-sleep.service` wrote
  ~2.1G on every sleep under scripted stage 1, long before this migration. It
  presented as "suspend hangs with the fan on".
- **`emergencyAccess` was on for exactly one boot.** `OnFailure` drops to a
  prompt asking for a root password that does not exist, so it cannot be used.
  `boot.initrd.systemd.emergencyAccess = true` makes it an *unauthenticated*
  root shell, which was carried deliberately for the first boot and removed
  after. If it is ever needed again, the option takes a password hash —
  `oneOf [ bool (nullOr (passwdEntry str)) ]` — which is strictly better.

## How to tell the unit is really there

This is the check that matters, because the failure mode is silence.
`ad38ffb` (2026-04-15) replaced `postResumeCommands` with a correct-looking
`restore-root` unit and never set `boot.initrd.systemd.enable`. Under scripted
stage 1 a systemd-initrd unit is **not rendered at all** — no error, no warning,
the option accepts the definition and the service simply never exists. The
rollback stopped happening and nothing said so. It survived four months because
the branch it landed on never evaluated.

Ask the initrd closure directly:

```sh
nix derivation show -r "$(nix eval --raw \
  '.#nixosConfigurations.<host>.config.system.build.initialRamdisk.drvPath')" \
  | grep -c restore-root
```

Non-zero means it is in the initrd. This answers the precise question `ad38ffb`
got wrong, without building anything.

Reading the rendered unit is worth it too — it shows whether the LUKS ordering
derived correctly:

```sh
nix eval --raw '.#nixosConfigurations.<host>.config.boot.initrd.systemd.units."restore-root.service".text'
```

A `just diff <ref>` showing the `initrd:` line move is weaker evidence: it moves
for any initrd change at all, so it cannot distinguish "the unit was rendered"
from "something else moved".

## And that it ran

The machine coming up proves nothing. Compare the `/root` subvolid across a
reboot:

```sh
findmnt -no SOURCE /        # or: awk '$5=="/"{print $NF}' /proc/1/mountinfo
```

It must change. On tenacity: 607 → 622 → 627 across successive boots, against
neighbours sitting at 257–265. A `/root` subvolid far above its siblings is the
rollback demonstrably running.

`journalctl -b 0 -u restore-root` has the unit's own log from the initrd.

## Related

- `WARN-impermanence.nix` — the module, with the full account in its history
  block.
- [history.md](history.md) — lived at `claude cave/lessons-learned-impermanence-stage1-migration.md`
  until 2026-09-02, when that directory was retired and this file moved into
  `wiki/` as a real page; [styleguide.md](styleguide.md) has why it counts as
  an exception to this wiki's usual "index over restatement" rule.
- [nixpkgs#527478](https://github.com/NixOS/nixpkgs/issues/527478) — LUKS under
  systemd initrd, the risk that did not bite here.
- [impermanence#320](https://github.com/nix-community/impermanence/issues/320) —
  someone hitting the `postResumeCommands` assertion after enabling stage 1. No
  fix in the thread. Most rollback recipes online are ZFS, where
  `zfs rollback` is atomic; the btrfs subvolume-delete approach has different
  constraints and the ZFS examples do not transfer.
