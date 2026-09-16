# Auto-suspend hang on nire-durandal, for agents

_Last modified: 2026-09-14_

Condensed from
[durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md), which keeps the
reasoning and the cycle log. **Status: mechanism partly identified, cause
not. Nothing under test.** `amdgpu.runpm=0` tried 2026-09-14, failed.

**Probably not an OS bug.** Elly reports the same hang under Windows on this
hardware years ago (recollection, not measurement), and the GPP0/GPP8
mitigation worked for years before failing in the last few months. Treat every
amdgpu finding below as symptom, not cause; suspect firmware or wear (PSU caps,
CMOS battery — unmeasured).

## Symptom

Enters S3, then will not wake by any input. Only a PSU power cut recovers it —
timed so DRAM survives on standby; held too long, RAM and the session go.

## Two failure shapes

| shape | kernel sees | recovery |
|---|---|---|
| SMU timeout | `resume of IP block <smu> failed -62` (`-ETIME`), `last_failed_dev = 0000:07:00.0` | PSU cut; RAM often lost |
| no-wake (common) | **nothing — reports `success`** | PSU cut; RAM usually kept |

## Traps

- **`/sys/power/suspend_stats` is not a hang detector.** It logged two known
  hangs as `success`. Only the SMU shape lands there.
- **The OS cannot detect the no-wake shape from inside.** `CLOCK_BOOTTIME`
  minus `CLOCK_MONOTONIC` accounted for 2473.6 s of a 2491 s pre-to-post window
  (17 s remainder across three cycles = normal overhead), so the CPU is not
  running during a hang. Not a resume-path wedge.
- **Pair dumps by order, not timestamp** — `pre` is stamped at suspend, `post`
  at resume; a pair never shares a stamp.
- **`1-6/power/wakeup_count` is always 0 and means nothing.** Keyboard wake
  arrives as a controller-level PME on `01:00.0`, never as the Moonlander's own
  remote wakeup.
- **`Refused to change power state from D0 to D3hot` + `MODE1 reset` fire on
  every cycle**, successes included, on every boot back to July. Standing
  suspect (Navi 22 `1002:73df` held in D0 across S3), never a discriminator.
- Resume logs for a hang and a clean cycle are byte-identical. **So is the
  descent** (compared 2026-09-16 against a menu-suspend/keyboard-wake control):
  only device-resume ordering differs. Finer resolution needed for any signal.
- **Why hangs leave no evidence:** `printk: Suspending console(s)` — after that
  point messages go to the RAM ring buffer and only reach disk if the machine
  resumes. Lost means unflushed, not unprinted.
- **A serial console may still capture nothing.** The CPU is not executing
  during a hang, and nothing records what nothing prints. Serial helps only if
  the kernel is running and printing into a torn-down console.
- Nothing else in the repo touches the suspend path: the only
  `powerDownCommands`/`resumeCommands` are the probe's, `sleep.target` has one
  dependency, no `/etc/systemd/system-sleep` hooks.
- **Auto vs manual is NOT the discriminator.** Both hang; a manual cycle hung
  2026-09-14. An early 35-suspend requester tally made auto look causal.
- **"A `pre` with no `post` is a hang" is WRONG.** `powerDownCommands` fires on
  shutdown too, so every reboot leaves an orphan `pre`. Use the power-cycle
  delta.
- **"Power-cycle count moved = hang" is WRONG** (corrected 2026-09-15). `+1` is
  baseline; it would flag every suspend. Only `> 1` is a hang.
- Detector-labelled totals 2026-09-14→15: **1 hang, 6 clean.** Cycles predating
  smartmontools are memory-labelled and unverifiable.

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
[suspend-probe-durandal.nix](../../flake/modules/hosts/durandal/fixes/suspend-probe-durandal.nix)
— writes `/var/log/suspend-probe/`, `sync`'d; `/var/log` is its own btrfs
subvolume, outside the wiped root.

**Kernel confound resolved.** The 02:24 reboot made `runpm=0` live and moved
the kernel 6.18.43 → 6.18.51 together. The hang continued, so neither worked
and no reboot need be spent separating them. Kernel 6.18.51 from here.

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

  Baseline measured with a controlled menu-suspend/keyboard-wake 2026-09-15
  (`nvme0` 2862→2863). Cycle 7 was `+3` = two cuts.

## See also

[durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md) ·
[hosts.md](../hosts.md) · [lessons-learned.md](../lessons-learned.md)
