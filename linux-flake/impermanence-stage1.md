# Converting impermanence to systemd stage 1

**Done on 2026-08-10, on `flake-parts-consolidation`.** `WARN-impermanence.nix`
now wipes `/root` from `boot.initrd.systemd.services.restore-root`, and the
`boot.initrd.postResumeCommands` version is gone. What follows is the note that
guided that, corrected where it turned out to be wrong, and kept in full because
the result **evaluates but has never booted**.

It was not a free decision. The 2026-08-07 nixpkgs flipped
`boot.initrd.systemd.enable` to default `true`, and warns that scripted initrd is
"deprecated and scheduled for removal in 26.11" — the release that same bump
moved both hosts onto. Updating the lock broke evaluation of both hosts at once,
on exactly the assertion this file predicted.

Both machines still *run* the scripted version, as do `origin/main` and
`origin/flake-parts`. Reverting means restoring `postResumeCommands` **and**
pinning `boot.initrd.systemd.enable = false`; the two cannot overlap.

It had been attempted once before, in `ad38ffb` (2026-04-15), in a way that
silently did nothing.

---

## Why the first attempt failed

`ad38ffb` replaced `postResumeCommands` with
`boot.initrd.systemd.services.restore-root` — a correct-looking unit — but
nothing ever set `boot.initrd.systemd.enable = true`.

Under scripted stage 1 a systemd-initrd unit is **not rendered into the initrd
at all**. It is not an error and produces no warning: the option accepts the
definition, the config evaluates, and the service simply never exists. The root
rollback stopped happening, and nothing said so.

It survived four months because the branch it landed on never evaluated, so it
was never deployed. Had it been, `/root` would have quietly stopped being wiped.

**The tell**, if you are ever unsure whether a change reached the initrd:

```sh
just diff <ref>          # `initrd:` line, sampled by host-fingerprint.nix
```

Editing the systemd unit under scripted stage 1 leaves the initrd drvPath
**byte-identical**. Switching back to `postResumeCommands` moved it immediately.
That asymmetry is the whole diagnosis in one command.

## The option that has to come first

```nix
boot.initrd.systemd.enable = true;
```

This was `mkEnableOption` defaulting **false** through 26.05 — which is what the
rest of this file was written against. As of the 2026-08-07 nixpkgs it reads

```nix
enable = mkEnableOption "systemd in initrd" // { default = true; };
```

in `nixos/modules/system/boot/systemd/initrd.nix:195`. Systemd stage 1 is now the
default, and it is *scripted* initrd that needs the explicit opt-out.

Do not confuse it with `boot.loader.systemd-boot.enable`, which both hosts *do*
set. That is the EFI **bootloader**; this is systemd inside the **initramfs**.
Unrelated options, similar names — and the likeliest reason the first attempt
looked finished.

Once it is on, `postResumeCommands` becomes a hard error rather than a silent
no-op: `nixos/modules/system/boot/systemd/initrd.nix` lists it among the
unsupported stage-1 options, alongside `preDeviceCommands`, `postDeviceCommands`,
`postMountCommands` and friends. So the two mechanisms cannot overlap, and the
switch has to be atomic.

## The unit

Ordering, from the [stage-1 migration guide](https://discourse.nixos.org/t/migrating-to-boot-initrd-systemd-and-debugging-stage-1-systemd-services/54444):

```nix
boot.initrd.systemd.services.restore-root = {
    description = "Rollback btrfs rootfs";
    wantedBy    = [ "initrd.target" ];
    after       = [ "initrd-root-device.target" ];
    before      = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''…same btrfs script…'';
};
```

`initrd-root-device.target` is the host-generic synchronisation point: it is
reached once the root block device exists, after LUKS unlock, whatever the
volume is called.

### If you order against the LUKS units directly instead

The unit name is derived from the **volume**, not the host. nixpkgs writes
`boot.initrd.luks.devices.<n>` as field 1 of the initrd crypttab
(`luksroot.nix`, `stage1Crypttab` — `"${n} ${v.device} ..."`), and
`systemd-cryptsetup-generator` names the unit after that field. Both machines use
`enc`, so:

```
dev-mapper-enc.device
systemd-cryptsetup@enc.service
```

Derive them rather than hardcoding:

```nix
luksVolumes = builtins.attrNames config.boot.initrd.luks.devices;
requires    = map (v: "dev-mapper-${v}.device") luksVolumes;
after       = (map (v: "dev-mapper-${v}.device") luksVolumes)
           ++ (map (v: "systemd-cryptsetup@${v}.service") luksVolumes);
```

**The version in `ad38ffb` said `systemd-cryptsetup@nire-durandal.service`** —
the hostname, not the volume. No such unit is ever generated, and `After=` a
unit that does not exist is a silent no-op, so it never ordered anything even on
durandal. Do not "fix" it by interpolating `networking.hostName`; that produces
the same non-existent unit with a different name.

`Requires=` and `After=` are independent — the first is an activation
dependency, the second is pure ordering, and systemd.unit(5) says to pair them.
`Requires=` alone can run before the device exists; `After=` alone runs the
service and lets it fail rather than not running it.

## Hibernation — the safety property the conversion drops

`postResumeCommands` runs *after* the resume attempt. A successful hibernation
resume therefore skips the wipe: the property is in the option's name. A plain
`initrd.target` service has no equivalent, and would delete the root the restored
memory image expects.

Add the guard as part of the conversion:

```nix
unitConfig.ConditionKernelCommandLine = [ "!resume" ];
```

It fails in the safe direction — stops wiping rather than wiping a resuming
system. Neither host puts `resume` on the kernel command line today (durandal
has a swap device but no `boot.resumeDevice`; tenacity has no swap), so it
changes nothing now.

## Order of work

1. `boot.initrd.systemd.enable = true` on **one** host, nothing else changed.
   Build, switch, reboot, confirm it comes up. This is the risky step, not the
   unit: LUKS plus systemd initrd is where boots break — see
   [NixOS/nixpkgs#527478](https://github.com/NixOS/nixpkgs/issues/527478).
2. Only then swap `postResumeCommands` for the unit — they cannot coexist, since
   the option becomes an error once stage 1 is on.
3. Confirm the initrd actually changed: `just diff <ref>` must show the `initrd:`
   line move. If it does not, the unit is not being rendered and you are back
   where `ad38ffb` was.
4. Reboot and check `/root` was actually rolled back, not merely that the system
   booted. A rollback that silently stops looks exactly like a working system
   until the disk fills.
5. Second host only after the first has survived a few reboots.

### Corrections to that list, from doing it

**Step 1 as written is impossible.** "Nothing else changed" contradicts this
file's own "the switch has to be atomic" above: leaving `postResumeCommands` in
place while enabling stage 1 *is* the failed assertion. To isolate the risky
part, enable stage 1 and **drop the rollback block entirely** for that boot. One
boot without a wipe is harmless — it just leaves that boot's `/root` behind — and
it separates "does LUKS come up under systemd initrd" from "does the new unit
work". In the event this was not done: both landed together, so a failure to boot
has two candidate causes rather than one.

**Step 3 has a better check than the `initrd:` line.** That line moves for any
initrd change at all, so it cannot distinguish "the unit was rendered" from
"something else moved". Ask the initrd closure directly:

```sh
nix derivation show -r "$(nix eval --raw \
  '.#nixosConfigurations.<host>.config.system.build.initialRamdisk.drvPath')" \
  | grep -c restore-root
```

Non-zero means the unit is really in the initrd. That is the precise question
`ad38ffb` got wrong, and it is answerable without building anything.

Reading the rendered unit is worth it too — it shows whether the LUKS ordering
derived correctly:

```sh
nix eval --raw '.#nixosConfigurations.<host>.config.boot.initrd.systemd.units."restore-root.service".text'
```

## Related

- `WARN-impermanence.nix` — the module, with the full account in its `history`
  block.
- `2026-08-09-TENACITY-PLAN.md` if it exists, or `TENACITY-PLAN.md` — tenacity's
  impermanence was deferred on the strength of this.
- [nix-community/impermanence#320](https://github.com/nix-community/impermanence/issues/320)
  — someone hitting the `postResumeCommands` assertion after enabling stage 1.
  No fix in the thread; note that most impermanence rollback recipes online are
  ZFS, where `zfs rollback` is atomic. The btrfs subvolume-delete approach here
  has different constraints and the ZFS examples do not transfer.
