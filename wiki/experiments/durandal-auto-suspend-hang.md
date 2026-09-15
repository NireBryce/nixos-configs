# Auto-suspend hang on nire-durandal

_Last modified: 2026-09-14_

`nire-durandal` suspends into S3 and then cannot be woken — keyboard, power
button, nothing — until power is physically removed at the PSU. **Status:
mechanism partly identified, cause not. Nothing currently under test —
`amdgpu.runpm=0` was tried and failed.** Recovery
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

**The power-cycle detector is validated.** Cycle 7 moved `nvme0` 2854 → 2857
and `sda` 6162 → 6165 across one 58 s window — three power cuts, recorded
without anyone having to remember them. Counters are cumulative, so only
*deltas* carry signal.

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

Four hangs in seven. Cycle 7 is the one that matters: a **manual** suspend,
hung, with `amdgpu.runpm=0` active — killing both the auto-vs-manual
hypothesis and the mitigation in a single cycle. It is also the first cycle
labelled by the detector rather than from memory. Only cycle 1 was ever
visible to `suspend_stats`.

## Reading the dumps

**`## drive power cycles` is the signal.** A cycle whose count moves is a
cycle that hung, because recovering from one means cutting PSU power and the
drives count that. Validated against a real hang 2026-09-14.

**Do not use pre/post pairing as a hang signal.** "A `pre` with no `post` is a
hang" was written here and is wrong: `powerDownCommands` fires on shutdown as
well as sleep, so **every reboot leaves an orphan `pre`**. Pair by order when
you do pair — `pre` is stamped at suspend and `post` at resume, so a pair never
shares a stamp.

`## requester` labels the cycle auto or manual. Worth having even though auto
turned out not to be the discriminator — it is what caught cycle 7 being
manual.

## See also

- [hosts.md](../hosts.md) — the host roster.
- [lessons-learned.md](../lessons-learned.md) — the KDE hybrid-sleep trap, a
  different suspend failure on this fleet.
