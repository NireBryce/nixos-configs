# Auto-suspend hang on nire-durandal, for agents

_Last modified: 2026-10-02_

Source: [durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md).
**Status: mechanism partly identified, cause
not. Nothing under test.** `amdgpu.runpm=0` tried 2026-09-14, failed.

**Probably not an OS bug.** The user recalls the same hang under Windows on
this hardware years ago (recollection, not measurement); the GPP0/GPP8
mitigation worked for years, then failed. Treat amdgpu findings as symptom;
suspect firmware or wear (PSU caps, CMOS battery — unmeasured).

## Symptom

Enters S3, will not wake by any input. Only a PSU power cut recovers it; held
too long, RAM and the session are lost.

## Two failure shapes

| shape | kernel sees | recovery |
|---|---|---|
| SMU timeout | `resume of IP block <smu> failed -62` (`-ETIME`), `last_failed_dev = 0000:07:00.0` | PSU cut; RAM often lost |
| no-wake (common) | **nothing — reports `success`** | PSU cut; RAM usually kept |

## Traps

- **`/sys/power/suspend_stats` is not a hang detector** (logged two known
  hangs as `success`); only the SMU shape lands there.
- **The OS cannot detect the no-wake shape from inside.** `CLOCK_BOOTTIME` -
  `CLOCK_MONOTONIC` covered 2473.6 s of a 2491 s pre-to-post window (rest =
  normal overhead): the CPU is not running during a hang, not a resume-path
  wedge.
- **Pair dumps by order, not timestamp** (`pre` stamped at suspend, `post` at
  resume).
- **`1-6/power/wakeup_count` is always 0, meaningless.** Keyboard wake is a
  controller-level PME on `01:00.0`, never the Moonlander's own remote wakeup.
- **`Refused to change power state from D0 to D3hot` + `MODE1 reset` fire on
  every cycle**, successes included, on every boot back to July. Standing
  suspect (Navi 22 `1002:73df` held in D0 across S3), never a discriminator.
- Resume logs for hang and clean cycle are byte-identical, **as is the
  descent** (vs a menu-suspend/keyboard-wake control, 2026-09-16); only
  device-resume ordering differs. Finer resolution needed for any signal.
- **Why hangs leave no evidence:** after `printk: Suspending console(s)`
  messages go to the RAM ring buffer and reach disk only if the machine
  resumes. Lost = unflushed, not unprinted.
- **A serial console may capture nothing**: the CPU is not executing during a
  hang. It helps only if the kernel runs and prints into a torn-down console.
- Nothing else in the repo touches the suspend path: only the probe's
  `powerDownCommands`/`resumeCommands`; `sleep.target` has one dependency; no
  `/etc/systemd/system-sleep` hooks.
- **Auto vs manual is NOT the discriminator.** Both hang (manual hung
  2026-09-14); an early 35-suspend tally made auto look causal.
- **`/etc` IS NOT EVIDENCE HERE.** An agent shell has its own mount namespace
  (65 mounts vs PID 1's 44) and synthetic `/etc` (`/etc/profile` resolved into
  a VS Code FHS store path; `systemd-analyze cat-config` said every config
  "not found"). Use `/run/current-system/etc/...` and `/proc/1/mountinfo`.
- **Drive power-cycle counts survive across generations** (drive firmware), so
  a probe-less generation can still be tested: note count, boot, suspend,
  return, compare delta against suspend count.
- **"A `pre` with no `post` is a hang" is WRONG.** `powerDownCommands` fires on
  shutdown too, so every reboot leaves an orphan `pre`. Use the power-cycle
  delta.
- **"Power-cycle count moved = hang" is WRONG** (corrected 2026-09-15): `+1`
  is baseline; only `> 1` is a hang.
- Detector-labelled totals 2026-09-14→2026-10-02: **2 hangs (cycle 7;
  `20261002T233332Z-post`), 35 clean between them** — ~1 in 18. Cycles
  predating smartmontools are memory-labelled, unverifiable.
- **2026-10-02 hang:** auto, `deep`, 6.18.53, `nvme0` 2891→2894 (2 cuts; user
  recalled "2 or 3" — trust the counter), 94 s suspend→resume wall clock incl.
  both cuts (failed on first wake). `suspend_stats` success; GPU
  `suspend_noirq` 517 ms (baseline); `pre` vs prior clean `pre` differs only in
  per-cycle counters.

## Ruled out

**`amdgpu.runpm=0`** (tried and removed 2026-09-14; hung with it active, and
it did not change the `D0 to D3hot` refusal it targeted) · **dying CMOS
battery / gross standby-rail failure** (2026-09-16 IT8688E: `Vbat` 3.19 V,
`3VSB` 3.26 V, `+12V` 12.18 V, `+5V` 5.01 V, all healthy — but sampled AWAKE
only, so wear generally is NOT cleared; PSU substitution still undone;
transcript:
[durandal-superio-probe-runbook-2026-09-16.md](durandal-superio-probe-runbook-2026-09-16.md))
· **the 2026-08-10 stage-1/hibernation migration** (abrupt-ending boots run
back to 2025-12-02, the retention limit, and do not cluster after August; and
S3 resumes from RAM, never entering an initrd) ·
`wakeupsourcehelper` (no wakeup-state change in pre/post diffs) · **s2idle**
(SMU failure occurred under it; no `amd_pmc`, no `s0i3` on this desktop part,
so it cannot reach hardware sleep and costs near-idle power) · **BIOS** (bug
predates F21c per the user, 2026-09-14; the journal counts never supported it —
0-in-27 under F18d is ~46% likely at the observed rate) · Resizable BAR (off,
BAR0 256 MB) · amdgpu memory eviction (0, and 27 GB swap present) · ring
timeouts, reset failures, VM faults (0) · PTXH as a rogue wake source (it is
the keyboard wake path; disabling it costs wake-on-keyboard).

## Under test

Nothing. Instrumentation only:
[suspend-probe-durandal.nix](../../flake/modules/host-config/durandal/fixes/suspend-probe-durandal.nix)
— writes `/var/log/suspend-probe/`, `sync`'d; `/var/log` is its own btrfs
subvolume, outside the wiped root.

**Kernel confound resolved:** `runpm=0` and kernel 6.18.43 → 6.18.51 went live together at the 02:24 reboot
and the hang continued, so neither worked. Kernel 6.18.51 from here.

## Instrumentation

Per cycle: requester, sleep mode, `suspend_stats`, `/proc/acpi/wakeup`, GPE
counters, PCI + USB wakeup, `/sys/class/wakeup`, drive power cycles, and (from
2026-09-15) **GPU state** — `power_dpm_state`, forced perf level, all
`pp_dpm_*` with active marker, busy%, link speed/width, hwmon power/temp/volts.
Added because nothing else in the dump differs between hang and clean.
`pm_print_times=1` via tmpfiles logs per-device suspend/resume durations.

Not done: **`/sys/power/pm_test`** (`core`/`platform`/`devices`/`freezer` —
bisects where suspend fails without entering S3; if `devices`+`platform` pass
while real S3 hangs, the fault is beyond the kernel) · **serial console +
`no_console_suspend=1`** (`/dev/ttyS0`, 16550A at 0x3f8 — the only way to
observe the failure, since the CPU is not executing during it; needs a cable
and a second machine) · **`umr`** (packaged, but near-useless here: needs the
GPU to respond, which is what fails).

## 26.05 -> 26.11 boundary

75-day generation gap: **221** (2026-05-30, `26.05.20260523`) -> **222**
(2026-08-13, `26.11.20260807`). Both closures still in the store.

| | 221 | 222 |
|---|---|---|
| `sleep.conf` | `[Sleep]` only | 3x `Allow*=false` |
| `nohibernate` | no | yes |
| kernel | 6.18.33 | 6.18.43 |
| **powerdevil** | **6.6.5** | **6.7.4** |
| systemd | 260.1 | 261.1 |

b550 udev rule present in 221/222/227 — not lost here. The `sleep.conf` change
is the documented hybrid-sleep breakage, closed by `SleepMode=1` (still in
`powerdevilrc`). **PowerDevil 6.6.5 -> 6.7.4 is untested** and is what
initiates auto-suspend.

**Gens 218-221 are bootable**, **not being chased (2026-09-16)**: effort stays
on logging. Pre-upgrade tree is in git, not the boot menu — gen 221
~`887cdc6f` (2026-05-30), gen 222 just before the 2026-08-14 cluster (skill
`git-archaeology` for the renames both predate).

**Caveat:** abrupt-ending boots appear from 2025-12-02, including two
pre-boundary 26.05 boots. Data cannot say whether the boundary caused it or
worsened it.

## Per-device timing baseline

`pm_print_times` live since 2026-09-16. First 3 cycles: **1140 callbacks, zero
non-zero returns** either direction.

| device | callback | measured |
|---|---|---|
| `0000:07:00.0` GPU | `pci_pm_suspend_noirq` | **522 / 521 / 515 ms** |
| `0000:07:00.0` GPU | `pci_pm_resume` | 471 ms |

GPU is the **slowest device on the descent**; `suspend_noirq` is the last
device phase before firmware handoff. ~1% spread = baseline. **2026-10-02 hang
read 517 ms, returned 0** — the hang is past this phase, not in it.
USB `usb_dev_resume` times (1-2 1.7s, 1-1 1.6s, 1-10 1.27s) are re-enumeration, **not suspects**.

## Reading the dumps

- `## requester` — `org_kde_powerdevil` = idle timeout (auto);
  `plasmashell` / `kscreenlocker` = a person asked.
- `## drive power cycles` — only in-band evidence of the no-wake shape.
  Counters are cumulative; read **deltas**, and **`+1` is baseline, not a
  hang** — this board removes drive power on every S3 suspend.

  | delta | meaning |
  |---|---|
  | `0` | not a suspend (reboot) |
  | `+1` | clean suspend |
  | `+N > 1` | hang; `N − 1` PSU cuts |

  Baseline: controlled menu-suspend/keyboard-wake 2026-09-15 (`nvme0`
  2862→2863). Cycle 7 was `+3` = two cuts.

## See also

[durandal-suspend-instrumentation-state.md](durandal-suspend-instrumentation-state.md) (what is running on the machine) · [hosts.md](../hosts.md)
