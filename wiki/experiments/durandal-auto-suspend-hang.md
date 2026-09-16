# Auto-suspend hang on nire-durandal

_Last modified: 2026-09-14_

`nire-durandal` suspends into S3 and then cannot be woken — keyboard, power
button, nothing — until power is physically removed at the PSU. **Status:
mechanism partly identified, cause not. Nothing under test.** Elly reports the
same failure under **Windows** on this hardware years ago, which — if it holds
— makes this firmware or hardware, not an OS bug, and makes every amdgpu
finding below a symptom rather than a cause. Recovery
is a timed PSU cut that resets the GPU while DRAM stays alive on standby; hold
it too long and RAM goes, taking the session.

> **Condensed version:**
> [durandal-auto-suspend-hang-for-agents.md](durandal-auto-suspend-hang-for-agents.md)
> — the same ground with the narrative stripped out, for an agent (or a human
> in a hurry) loading it mid-task. Both siblings get edited in the same change.

## Contents

- [Two failure shapes](#two-failure-shapes)
- [The machine is asleep, not wedged](#the-machine-is-asleep-not-wedged)
- [Established](#established)
- [Ruled out](#ruled-out)
- [Under test](#under-test)
- [Progress](#progress)
- [Instrumentation](#instrumentation)
- [The 26.05 -> 26.11 boundary](#the-2605---2611-boundary)
- [Reading the dumps](#reading-the-dumps)
- [See also](#see-also)
## Two failure shapes

Instrumented cycles so far separate into two, and they are not the same bug:

| shape | what the kernel sees | recovery |
|---|---|---|
| **SMU timeout** | `resume of IP block <smu> failed -62` (`-ETIME`), `last_failed_dev = 0000:07:00.0` | PSU cut; RAM often lost |
| **no-wake** | **nothing — reports `success`** | PSU cut; RAM usually kept |

The second is the common one and the reason this is hard.

## The machine is asleep, not wedged

Measured 2026-09-14. Across one boot's cycles, `CLOCK_BOOTTIME` minus
`CLOCK_MONOTONIC` accounted for 2473.6 s of a 2491 s total pre-to-post window —
a 17 s remainder across three cycles, which is ordinary device suspend/resume
overhead.

So during a hang **the CPU is not running.** The machine is genuinely in S3 and
will not come out. It is not a kernel wedge partway through resume, which is
what the identical resume logs had suggested.

Two consequences, both load-bearing:

- **The OS cannot detect this from inside**, because nothing is executing while
  it is stuck. No probe cleverness changes that.
- **`/sys/power/suspend_stats` is not a hang detector.** It logged two
  known hangs as `success`. Only the SMU variant lands there, because that one
  happens inside a resume the kernel is awake for.

## Established

- **Auto-suspends are identifiable**: `logind` requester `org_kde_powerdevil`
  is the idle timeout; `plasmashell` / `kscreenlocker` mean a person asked.
- **Both auto and manual suspends hang.** A manual cycle hung on 2026-09-14
  (`plasmashell`), falsifying the earlier reading that PowerDevil's idle
  timeout was the discriminator. An earlier 35-suspend requester tally made
  auto look causal; it is just the trigger hit most often.
- **It predates Linux.** Elly recalls the same hang under Windows while
  dual-booting, and it is part of why this machine moved to Linux. Recorded as
  recollection, not measurement — but if right, no driver-level explanation can
  be the root cause, and `resume of IP block <smu> failed -62` is the driver
  *reporting* unresponsive hardware rather than causing it.
- **The GPP0/GPP8 mitigation worked for years and stopped in the last few
  months.** A long-standing fault adequately masked, recently crossing a
  threshold where the mask stopped sufficing. Things that change on that
  timescale are wear, not software — PSU capacitors (S3 is a very low-load
  state, and the recovery *is* cutting PSU power), CMOS battery, board caps.
  None of this is measured yet.
- **`Refused to change power state from D0 to D3hot` + `MODE1 reset` fires on
  every suspend**, on every boot back to July. The Navi 22 (`1002:73df`) never
  leaves D0 across S3. This is the standing suspect — a GPU held in D0 through
  S3 is a known way to be unable to resume — but it is *not* a discriminator,
  since it also fires on every successful cycle.

## Ruled out

- **`wakeupsourcehelper`** — it runs before PowerDevil suspends and not before
  manual ones, which looked like the difference. Pre/post diffs show no wakeup
  state change attributable to it.
- **s2idle** — tested 2026-09-13. The SMU failure happened *under* s2idle, so
  it is not protective; and there is no `amd_pmc` module, no `amd_pmc` debugfs
  and no `s0i3` support on this desktop part, so it cannot reach hardware sleep
  at all and costs near-idle power for nothing. Reverted; do not retry.
- **The BIOS.** F18d → F21c was flashed 2026-08-22, and journal counts appeared
  to implicate it. They cannot: 0 failures in 27 F18d suspends is ~46% likely at
  the observed rate even if nothing changed. The user confirms the bug predates
  F21c (2026-09-14).
- **`amdgpu.runpm=0`** — tried 2026-09-14, removed the same day. The machine
  hung with it active, and it did not even change the `Refused to change power
  state from D0 to D3hot` it was aimed at.
- **A dying CMOS battery, and gross standby-rail failure.** Measured
  2026-09-16 with the IT8688E superio: `Vbat` 3.19 V, `3VSB` 3.26 V, `+12V`
  12.18 V, `+5V` 5.01 V — all healthy. Transcript:
  [durandal-superio-probe-runbook-2026-09-16.md](durandal-superio-probe-runbook-2026-09-16.md).
  This does **not** clear wear generally: every reading was taken while the
  machine was awake, and nothing can sample during S3. PSU substitution is
  still the only decisive test and has not been done.
- **The 2026-08-10 stage-1 / hibernation migration.** Plausible on timing, but
  boots ending abruptly (no shutdown sequence — the shape a lost PSU race
  leaves) run back to **2025-12-02**, the limit of journal retention, and do
  not cluster after August. Mechanically it could not have mattered either:
  S3 resumes from RAM and never enters an initrd. Nothing else in the repo
  touches the suspend path — the only `powerDownCommands`/`resumeCommands` are
  the probe's, `sleep.target` has one dependency, and there are no
  `/etc/systemd/system-sleep` hooks.
- **Resizable BAR** — off; GPU BAR0 is 256 MB.
- **amdgpu memory eviction**, **ring timeouts, reset failures, VM faults** —
  zero occurrences; 27 GB of swap present, so the eviction precondition fails.
- **PTXH as a rogue wake source.** `01:00.0` is the only device with wakeup
  activity, but that is because **it is the keyboard wake path** — a keypress
  arrives as a controller-level PME, never as the Moonlander's own remote
  wakeup, so `1-6/power/wakeup_count` stays 0 and means nothing. Disabling PTXH
  would cost wake-on-keyboard for real. Not a fault.

## Under test

Nothing is being tested right now. Instrumentation only:

- **[suspend-probe-durandal.nix](../../flake/modules/hosts/durandal/fixes/suspend-probe-durandal.nix)**
  — dumps wakeup, GPE and drive state to `/var/log/suspend-probe/` around every
  suspend, `sync`'d so it survives the power cut. `/var/log` is its own btrfs
  subvolume, outside the wiped root.

## Progress

**The probe and smartmontools are live** (2026-09-13 / 2026-09-14).
`amdgpu.runpm=0` was live from the 02:24 reboot until it was removed the same
day, having failed.

**The power-cycle detector works, once read correctly.** Cycle 7 moved `nvme0`
2854 → 2857 across a 58 s window — `+3`, i.e. two PSU cuts above the `+1`
baseline. Counters are cumulative, so only *deltas* carry signal, and only
deltas **above 1** mean anything.

**The kernel confound resolved itself.** That reboot made `amdgpu.runpm=0`
live *and* moved the kernel 6.18.43 → 6.18.51 (the latter via a `flake.lock`
update, not deliberately), which would have made a success unattributable. The
hang continued, so neither worked and no reboot needs to be spent separating
them. Kernel is 6.18.51 from here on.

Cycles, all 2026-09-14 UTC. Outcomes are the user's — nothing in the dumps yet
separates a hang from a clean resume:

| # | window | mode | trigger | slept | outcome |
|---|---|---|---|---|---|
| 1 | 03:21→03:44 | s2idle | auto | 23 m | **hang** — SMU `-ETIME`, cold boot, RAM lost |
| 2 | 03:52→04:20 | deep | auto | 29 m | **hang** — PSU race, RAM kept |
| 3 | 04:28→04:29 | deep | auto | 70 s | **hang** — PSU race, RAM kept |
| 4 | 04:34→04:46 | deep | auto | 11 m | clean, woke on keyboard |
| 5 | 04:54→04:55 | deep | auto | 21 s | clean |
| 6 | 05:07→05:57 | deep | **manual** | 50 m | clean |
| 7 | 06:52→06:53 | deep | **manual** | 58 s | **hang** — PSU race ×3, RAM kept, `runpm=0` active |

Cycle 7 is the one that matters: a **manual** suspend, hung, with
`amdgpu.runpm=0` active — killing both the auto-vs-manual hypothesis and the
mitigation in one cycle. Only cycle 1 was ever visible to `suspend_stats`.

**Detector-labelled cycles since** (2026-09-14 → 15): **one hang (cycle 7),
six clean.** Cycles 1–6 predate smartmontools and are labelled from memory
only — they can never be verified. Hangs are therefore much rarer than the
early "every auto-suspend" reading suggested, and short sleeps are not
inherently suspicious: 14 s, 51 s and 450 s cycles all read clean.

## Instrumentation

**Recorded per cycle** by
[suspend-probe-durandal.nix](../../flake/modules/hosts/durandal/fixes/suspend-probe-durandal.nix):
requester, sleep mode, `suspend_stats`, `/proc/acpi/wakeup`, GPE counters, PCI
and USB wakeup state, `/sys/class/wakeup`, drive power cycles, and — added
2026-09-15 — **GPU state**: `power_dpm_state`, forced performance level, every
`pp_dpm_*` table with its active marker, `gpu_busy_percent`, link speed and
width, and hwmon power/temp/voltage. That last one exists because nothing else
in the dump differs between a hang and a clean cycle; if the card goes into
suspend in a different state, this is where it would show.

`pm_print_times` is enabled via tmpfiles, so the kernel logs every device's
suspend and resume duration.

**Why a hang leaves no evidence, precisely.** The descent logs
`printk: Suspending console(s)`, after which kernel messages go to the RAM ring
buffer and only reach disk *if the machine resumes*. When it doesn't, they are
lost — not unprinted, unflushed. The kernel may well be saying what is wrong,
into a buffer nobody gets to read.

**But the gap may genuinely be empty.** `CLOCK_BOOTTIME` minus
`CLOCK_MONOTONIC` showed the CPU is not executing during a hang, and nothing
can record what nothing is printing. A serial console only helps in the case
where the kernel *is* running and printing into a torn-down console; on the
cycles observed so far it would likely have captured nothing. That is an
argument against buying the cable first, not for it.

**The descent is identical between a hang and a clean cycle** at current
logging detail — compared 2026-09-16, hang cycle against the
menu-suspend/keyboard-wake control. The only differences were device resume
*ordering* and one incidental slab warning. Any signal there needs finer
resolution than is currently enabled.

**Available and not done**, with what each would buy:

| option | buys | cost |
|---|---|---|
| `/sys/power/pm_test` (`core`/`platform`/`devices`/`freezer`) | bisects *where* suspend fails without entering S3. If `devices` and `platform` pass while real S3 hangs, the failure is beyond the kernel — closing off a lot of speculation | minutes, run by hand |
| serial console + `no_console_suspend=1` | the **only** way to observe the failure, since the CPU is not executing during it. `/dev/ttyS0` is real hardware here (16550A at 0x3f8) | a cable and a second machine |
| `umr` (packaged in nixpkgs) | AMD register-level debugging | **near-zero here** — it needs the GPU to respond, which is exactly what fails |

## The 26.05 -> 26.11 boundary

Elly recalls the hangs starting at a NixOS upgrade that forced a boot-type
change. Generation timestamps place it exactly: a **75-day gap** between
gen 221 (2026-05-30, `26.05.20260523`) and gen 222 (2026-08-13,
`26.11.20260807`). Both closures survive in the store, so this is a real
before/after pair rather than inference.

| | gen 221 (pre) | gen 222 (post) |
|---|---|---|
| `sleep.conf` | `[Sleep]` only | `AllowHibernation=false`, `AllowHybridSleep=false`, `AllowSuspendThenHibernate=false` |
| `nohibernate` kernel param | no | yes |
| kernel | 6.18.33 | 6.18.43 |
| **PowerDevil** | **6.6.5** | **6.7.4** |
| systemd | 260.1 | 261.1 |

The b550 udev rule is present in 221, 222 **and** 227 — it was not lost here.

The `sleep.conf` change is the one [lessons-learned.md](../lessons-learned.md)
records as having broken suspend outright (logind answering
`CanHybridSleep=no` and *dropping* the request), fixed with `SleepMode=1`,
which `powerdevilrc` still carries. That is closed. **PowerDevil's own
6.6.5 -> 6.7.4 jump at the same moment is not** — it is what initiates
auto-suspend, and nobody has looked at it. The earlier diagnosis may have been
correct but incomplete.

**Generations 218-221 are still bootable**, so the boundary is directly
testable — see Reading the dumps for why drive power-cycle counts make that
test work even on a generation with no probe.

**Not being chased further (decided 2026-09-16).** Booting gen 221 would test
this directly, but the hardware and config hypotheses have each failed in turn
and the instrumentation is what has actually produced results. Effort stays on
logging. If the boundary ever needs revisiting, the pre-upgrade tree is
recoverable from git rather than from the boot menu — gen 221 was built
2026-05-30, putting it at or just before `887cdc6f` ("changed a lot of
modules"); gen 222 was built 2026-08-13, just before the 2026-08-14 cluster
(`76f3b0ed`, `d6f8b8ad`). Skill `git-archaeology` covers finding a file across
the renames both dates predate.

**Timeline caveat:** boots ending abruptly appear from 2025-12-02, and boots
`-9` and `-8` (both pre-boundary, on 26.05, 53 and 60 suspends) end abruptly
too. Either abrupt endings have other causes, or the problem predates the
boundary and the upgrade worsened it. The data cannot separate those.

## Reading the dumps

**`## drive power cycles` is the signal — but `+1` is the baseline, not a
hang.** This board removes drive power on every S3 suspend (NVMe fully
re-inits, SATA links drop, root hubs lose power, all on every cycle), so a
clean suspend already costs one.

| delta | meaning |
|---|---|
| `0` | not a suspend — a reboot does this |
| `+1` | **clean suspend** |
| `+N > 1` | hang; `N − 1` PSU cuts |

Measured with a controlled menu-suspend/keyboard-wake on 2026-09-15 (`nvme0`
2862 → 2863, `sda` 6170 → 6171), so the baseline is confirmed rather than
assumed.

The rule first written here was "a cycle whose count moves is a cycle that
hung", which would flag **every** suspend this machine makes. It surfaced only
because Elly reported as successful a run of cycles the rule had called hangs —
the instrument disagreeing with the human was the instrument being wrong.

**Do not use pre/post pairing as a hang signal.** "A `pre` with no `post` is a
hang" was written here and is wrong: `powerDownCommands` fires on shutdown as
well as sleep, so **every reboot leaves an orphan `pre`**. Pair by order when
you do pair — `pre` is stamped at suspend and `post` at resume, so a pair never
shares a stamp.

**`/etc` is not evidence on this machine.** An agent shell here runs in its own
mount namespace (65 mounts against PID 1's 44) with a synthetic `/etc` — on
2026-09-16 `/etc/profile` resolved into a VS Code FHS store path, and
`systemd-analyze cat-config` reported every systemd config "not found", which
was an artifact of that namespace and not true of the machine. Read
`/run/current-system/etc/...` (a store path, namespace-independent) and
`/proc/1/mountinfo` instead. `AGENTS.md` and skill `impermanence-initrd` state
this for disks and mounts; it applies to `/etc` just as hard.

**Drive power-cycle counts work across generations.** The counter lives in the
drive's own firmware, so a hang during a session on an older generation — one
with no probe installed — is still recorded. Note the count before, boot the
other generation, suspend a few times, come back, and compare the delta against
the number of suspends.

`## requester` labels the cycle auto or manual. Worth having even though auto
turned out not to be the discriminator — it is what caught cycle 7 being
manual.

## See also

- [durandal-suspend-instrumentation-state.md](durandal-suspend-instrumentation-state.md)
  — every step run against the machine, what survives a reboot, and how to
  verify each rather than trust it.
- [hosts.md](../hosts.md) — the host roster.
- [lessons-learned.md](../lessons-learned.md) — the KDE hybrid-sleep trap, a
  different suspend failure on this fleet.
