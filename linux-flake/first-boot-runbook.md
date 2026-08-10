# First boot runbook — nire-tenacity

Getting `flake-parts-consolidation` from "evaluates" to "runs", using
`nh os boot` rather than `switch` so nothing changes until you choose the moment.

Written on the machine, 2026-08-10, from the state described below. Every
expected value here was read off this hardware, not assumed.

**Keep a copy off this machine.** If step 4 goes badly, the runbook you need is
on the device that will not boot.

---

## What is untested, honestly

Everything below has been *evaluated*. None of it has run.

| | |
|---|---|
| the branch | 172 commits on top of `origin/main`, never built, never switched, never booted |
| stage 1 | migrated scripted → systemd on 2026-08-10, **both halves at once** |
| nixpkgs | 26.05 (Apr 9) → **26.11** (Aug 7) — a release cycle, not a point bump |
| kernel | running 6.18.16 → **6.18.43** |
| handheld stack | `decky-loader`, `handheld-daemon`, `gamescope` never compiled by anything |
| Home Manager | first activation as a NixOS-integrated module |

The single highest risk is **LUKS under systemd initrd** — see
[nixpkgs#527478](https://github.com/NixOS/nixpkgs/issues/527478). It is also the
one thing that fails *before* you have a shell.

Because the stage-1 switch had to be atomic (`postResumeCommands` and systemd
stage 1 cannot coexist), a boot failure has two candidate causes rather than
one: systemd initrd itself, or the new `restore-root` unit. Step 5 tells them
apart.

## Why `boot` and not `switch`

`nh os boot` builds, installs the bootloader entry, and makes it the default for
the next boot. It activates nothing now, so the running system stays exactly as
it is until you reboot deliberately.

The trade is real and worth knowing: `switch` would activate Home Manager
*immediately*, surfacing any dotfile problem while you still have a working
shell. `boot` defers that to the reboot, so system + HM + initrd all land at
once. That is acceptable here only because the collision check has already been
done and came back clean — 42 of the 57 managed files are already
Home-Manager-owned symlinks, 13 do not exist yet, and none are real files.

## Starting state

| | |
|---|---|
| current generation | **60** (`/nix/var/nix/profiles/system-60-link`) |
| fallbacks in the menu | 56, 57, 58, 59 |
| target | `/nix/store/3kq8j5q1…-nixos-system-nire-tenacity-26.11.20260807.f13ff45` |
| `/boot` free | 850 MB of 1023 MB, 5 entries |
| boot menu timeout | **5 seconds** |
| plymouth | disabled — plain text console |
| `/root` subvolid | **607** (write this down; step 6 depends on it) |

---

## 0. Pre-flight

```sh
cd ~/projects/nix/flake-parts-condolidation-prime/nixos-configs
git status -sb                       # know what you are about to build
just modules                         # expect: no findings
just check                           # expect: no errors
```

Then the two things whose failure mode is initrd:

```sh
sudo btrfs subvolume list -a / | grep -E 'root-blank|path root$'
ls -l /persist/passwords/elly
```

Expect `root-blank` present (it was ID 265 today) and the password file present
(107 bytes). `users.mutableUsers` is `false` and root has **no** password, so
that file is the only way into the account after a boot.

## 1. Build only

```sh
just host=nire-tenacity build
```

Note the syntax — just takes variable assignments **before** the recipe name.
Plain `just build` targets *durandal*, because the justfile defaults
`host := "nire-durandal"`.

Roughly 700 derivations build and ~2800 are fetched (~6 GB). Most of the build
list is `preferLocalBuild` config generation that costs milliseconds; the real
compiles are Jovian's overlay packages, which `cache.nixos.org` will never have.

Running uncapped, so expect the handheld to be busy and hot. Plug it in.
**Ctrl-C is safe** — store writes are atomic, nothing has been activated, and a
later run resumes.

**If this fails, stop.** Nothing has changed and there is nothing to undo.

## 2. Make it the boot default

```sh
sudo nh os boot ~/projects/nix/flake-parts-condolidation-prime/nixos-configs/linux-flake \
    --hostname nire-tenacity
```

Verify before going further:

```sh
ls -1 /boot/loader/entries/          # expect a new nixos-generation-61.conf
readlink /nix/var/nix/profiles/system # expect system-61-link
grep -r default /boot/loader/loader.conf
```

The running system is still generation 60 at this point. `uname -r` will still
say 6.18.16 — that is correct, not a failure.

## 3. Before you press reboot

- **Fallback is generation 60.** It is still in the menu, along with 56–59.
- **The menu timeout is 5 seconds.** Start tapping the down arrow or space as
  soon as the screen lights up; there is no plymouth splash to warn you.
- **The LUKS prompt will look different.** systemd-cryptsetup asks, not the
  scripted `cryptsetup-askpass`. Different wording and placement is expected and
  is not a fault.
- Have the passphrase to hand, and this runbook on another device.

## 4. Reboot

```sh
sudo reboot
```

What is new this boot, in order:

1. systemd-boot menu — generation 61 is the default
2. **systemd stage 1 starts** instead of the scripted `stage-1-init.sh`
3. LUKS unlock via `systemd-cryptsetup@enc.service`
4. `restore-root.service` runs, ordered `After=initrd-root-device.target
   dev-mapper-enc.device systemd-cryptsetup@enc.service` and
   `Before=sysroot.mount`
5. `/root` is deleted and re-snapshotted from `root-blank`
6. stage 2, then `home-manager-elly.service` during activation

If `restore-root` fails, `OnFailure=emergency.target` fires and you get a root
shell **without a password prompt** — `boot.initrd.systemd.emergencyAccess` is
`true`, deliberately, because root has no password and the prompt would
otherwise be unenterable.

## 5. If it does not boot

Reboot and pick **generation 60** from the menu. That is a complete recovery;
generation 61 remains on disk and can be inspected later.

To tell the two candidate causes apart:

- **Never reached the LUKS prompt, or the prompt did not accept the passphrase**
  → systemd initrd itself, not the rollback. This is the nixpkgs#527478 class.
- **LUKS unlocked, then dropped to an emergency shell** → `restore-root`. You
  are in the initrd with a root shell; the interesting commands are:

  ```sh
  systemctl status restore-root
  journalctl -u restore-root
  btrfs subvolume list -a /mnt        # if /mnt is still mounted
  ```

  Most likely causes in order: `root-blank` missing, the `btrfs` binary absent
  from the initrd, or the by-uuid device node not present.

- **Booted, but to a black screen or no Steam session** → not stage 1 at all.
  Switch VT with Ctrl-Alt-F2 and log in as `elly`; the system is up.

Reverting the config itself is `git checkout` of the lock plus restoring
`postResumeCommands` and pinning `boot.initrd.systemd.enable = false` — the two
mechanisms cannot overlap, so it is one atomic edit. `impermanence-stage1.md`
has the detail.

## 6. After it boots — verify, in this order

**The rollback actually ran.** This is the one that fails silently, and the
reason to have written 607 down:

```sh
findmnt -no SOURCE /
```

The `subvolid=` must be **different from 607**. Same number means `/root` was
never recreated, the wipe did not happen, and the machine only *looks* fine.

```sh
journalctl -b 0 -u restore-root       # the unit's own log, from the initrd
```

Then the rest:

```sh
uname -r                                        # expect 6.18.43
readlink /nix/var/nix/profiles/system           # expect system-61-link
nixos-version                                   # expect 26.11.20260807.f13ff45

systemctl status home-manager-elly.service      # active (exited)
nix profile list | grep home-manager-path       # expect NOTHING: it self-removes
readlink -f ~/.zshrc                            # into /nix/store
ls /etc/profiles/per-user/elly/bin | wc -l      # the HM closure

systemctl status handheld-daemon
systemctl status decky-loader
systemctl status display-manager
```

The handheld stack is the part nothing has ever exercised. Expect to find
things there; none of it can stop the machine booting.

Two known cosmetic issues, already diagnosed, not worth chasing:

- `fzf` and `atuin` both bind **Ctrl-R**. Whichever initialises last wins.
- `programs.git.signing.format` warns because `home.stateVersion` is `22.11`.

## 7. Rolling back a boot that worked but was wrong

```sh
sudo nh os rollback          # or pick generation 60 in the boot menu
```

Home Manager is part of the system generation, so this takes home with it —
there is no separate HM rollback.

What a rollback does **not** undo: the `/root` wipe that already happened. That
is by design and is what the machine does every boot anyway.

## What this runbook cannot tell you

Whether any of it works. It was written from a machine running generation 60,
against a configuration that has been evaluated and never run. Every expected
value is either read from the current system or derived from the config — none
is an observation of the new one.

Report which you mean when you write up what happened: *evaluates*, *builds*, or
*runs*.

## Related

- `impermanence-stage1.md` — the stage-1 migration, and how to reverse it
- `home-manager-cutover.md` — the HM side in full, including `backupFileExtension`
- `lessons.md` §19 — `lsblk` and `findmnt` describe the sandbox, not the machine,
  if you are reading disk state from inside an agent shell
