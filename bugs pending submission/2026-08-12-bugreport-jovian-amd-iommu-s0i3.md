# Jovian-NixOS: `amd_iommu=off` blocks s0i3 on non-Deck handhelds with an NPU

Written 2026-08-12 against Jovian-NixOS
`57773e5c9efe27d298d732a2a061a380a5194090`, on a GPD G1617-02-L (Ryzen 7 8840U,
Phoenix), NixOS 26.11, kernel 6.18.43.

Paste-ready for <https://github.com/Jovian-Experiments/Jovian-NixOS/issues>.
Everything below the "Describe the bug" heading is the report; the last section
is local notes and should be dropped before filing.

---

## Describe the bug

`jovian.steamos.enableDefaultCmdlineConfig` adds `amd_iommu=off` to
`boot.kernelParams` for every Jovian host. That parameter comes from Valve's
`grub-steamos` defaults, which target the Steam Deck — Van Gogh silicon, which
has no NPU, so disabling the IOMMU there is free.

On a Phoenix / Hawk Point handheld (7840U, 8840U and relatives) the APU *does*
have an XDNA NPU. With the IOMMU off, the NPU cannot be used, and the machine
never enters hardware sleep at all: s2idle is entered, held, and exited
normally, but with **0% s0i3 residency**, drawing **23.65 W** the whole time.
The user-visible symptom is that the fan keeps running while the machine is
"asleep", and the battery is flat a couple of hours later.

This is not a subtle regression in sleep depth. It is the difference between
sleeping and not sleeping.

## Steps to reproduce

On a Jovian host with a Phoenix-or-later APU (anything with an NPU at
`class 0x118000`, driver `amdxdna`):

```console
$ grep -o 'amd_iommu=[a-z]*' /proc/cmdline
amd_iommu=off

$ systemctl suspend      # wait ~60s, then wake it

$ cat /sys/power/suspend_stats/last_hw_sleep
0

$ journalctl -b 0 -k | grep 'deepest state'
kernel: amd_pmc AMDI0009:00: Last suspend didn't reach deepest state
```

AMD's own diagnostic agrees, and refuses to run without `--force`:

```console
$ sudo amd-s2idle test --duration 60 --count 1 --force
❌ NPU is not supported with IOMMU disabled
🚫 Your system does not meet s2idle prerequisites!
...
| Duration | Hardware Sleep | Average Power |
| 0:01:05  | 0.00%          | 23.65W        |

System had low hardware sleep residency
```

## Expected behaviour

`amd_iommu=off` is not applied to hardware where it prevents s0i3. The Steam
Deck keeps it; other handhelds either do not get it, or get it only via the
Deck-specific profile, alongside `fbcon=rotate:1` which is already handled that
way.

## Root cause

`modules/steamos/boot.nix`, line 46, inside the block gated on
`cfg.enableDefaultCmdlineConfig` (which defaults to
`config.jovian.steamos.useSteamOSConfig`):

```nix
boot.kernelParams = [
  # From grub-steamos in jupiter-hw-support
  #  - https://github.com/Jovian-Experiments/jupiter-hw-support/blob/…/etc/default/grub-steamos
  "log_buf_len=4M"
  "amd_iommu=off"
  "amdgpu.lockup_timeout=5000,10000,10000,5000"
  ...
];
```

The surrounding comments carry Valve's reasoning for `amdgpu.lockup_timeout`,
`ttm.pages_min` and `amdgpu.sched_hw_submission`, but none for `amd_iommu=off`
— it appears to have been inherited with the rest of the list rather than
chosen. The file already recognises that some of Valve's flags are
hardware-specific: `fbcon=rotate:1` is commented out with "this is Steam Deck
specific so it goes into the Deck profile", and `fbcon=vc:4-6` is dropped
because of LUKS prompts. `amd_iommu=off` belongs in the same category and is
not currently treated that way.

## Fix

Verified on the affected machine: removing **only** `amd_iommu=off`, leaving
every other parameter unchanged, takes residency from 0% to 92.5% on the first
boot.

```
                        before          after
last_hw_sleep           0               59,213,866 µs  (59.2 s of a 64 s cycle)
"didn't reach deepest"  every cycle     0 occurrences
average power asleep    23.65 W         —
```

Moving the parameter into the Deck profile alongside `fbcon=rotate:1` would fix
this for every non-Deck host without changing Deck behaviour at all.

## Workaround

`enableDefaultCmdlineConfig` gates exactly one `mkIf` block, and that block sets
only `boot.kernelParams`, so it can be turned off and the list re-declared
without losing anything else:

```nix
{
  jovian.steamos.enableDefaultCmdlineConfig = false;

  # Valve's list, minus amd_iommu=off
  boot.kernelParams = [
    "log_buf_len=4M"
    "amdgpu.lockup_timeout=5000,10000,10000,5000"
    "ttm.pages_min=2097152"
    "amdgpu.sched_hw_submission=4"
    "amdgpu.dcdebugmask=0x20000"
    "audit=0"
  ];
}
```

This is what is running on the affected machine.

## Additional context

- Affected APU has its NPU at `0000:c4:00.1` (`1022:1502`, `\_SB_.PCI0.GP18.NPU_`),
  driver `amdxdna`. The device was in `D3hot`/`suspended` throughout, so this is
  not a case of the NPU visibly sitting awake — the platform simply will not
  enter s0i3 in this configuration.
- There is no S3 fallback on this hardware: `/sys/power/mem_sleep` offers only
  `[s2idle]`, so s0i3 has to work or there is no working suspend.
- `amd-s2idle` never named a blocking device. The NPU/IOMMU prerequisite was the
  only substantive failure it reported, and acting on it turned out to be
  correct.
- Two other suspects were ruled out: the EC fires `gpe0A` ~187 times during a
  65-second sleep (`ACPI: EC: GPE=0xa`), and the USB4 bridge at `00:08.3` carries
  a kernel `disabling D3cold for suspend` quirk. Both are still present on the
  working boot, so neither was responsible.

---

## Local notes — remove before filing

Found on `nire-tenacity` while chasing "suspend leaves the fan on". Fixed in
this repo by `linux-flake/modules/nireHost/tenacity/fixes/iommu-tenacity.nix`,
which is the workaround above; the module carries the full evidence.

Worth checking before filing, since none of it is verified here:

- Whether the ASUS ROG Ally / Ally X and Legion Go (same Phoenix/Hawk Point
  generation, both commonly run Jovian) reproduce this. If they do, the report
  is about the whole non-Deck handheld class rather than one GPD.
- Whether Valve's original reason for `amd_iommu=off` on Van Gogh still applies,
  which would argue for the Deck-profile move rather than dropping the flag
  outright.
- Whether Jovian would rather gate on NPU presence than on Deck-vs-not.

A separate bug in `amd-s2idle` was found while diagnosing this and is written up
in `2026-08-12-bugreport-amd-s2idle-residency-percent.md`. It does not affect
the conclusion here — it made the *fixed* run report "8939.39%" instead of
"89.39%" — but anyone reproducing this will hit it the moment their fix works.
