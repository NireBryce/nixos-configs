# Auto-suspend hang on nire-durandal

_Last modified: 2026-09-14_

`nire-durandal` suspends into S3 and then cannot be woken — keyboard, power
button, nothing — until power is physically removed at the PSU. **Status:
mechanism partly identified, cause not. One mitigation under test.** Recovery
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
- **Manual suspend works.** A 50-minute manual cycle resumed cleanly.
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
  the observed rate even if nothing changed. Elly confirms the bug predates
  F21c (2026-09-14).
- **Resizable BAR** — off; GPU BAR0 is 256 MB.
- **amdgpu memory eviction**, **ring timeouts, reset failures, VM faults** —
  zero occurrences; 27 GB of swap present, so the eviction precondition fails.
- **PTXH as a rogue wake source.** `01:00.0` is the only device with wakeup
  activity, but that is because **it is the keyboard wake path** — a keypress
  arrives as a controller-level PME, never as the Moonlander's own remote
  wakeup, so `1-6/power/wakeup_count` stays 0 and means nothing. Disabling PTXH
  would cost wake-on-keyboard for real. Not a fault.

## Under test

- **`amdgpu.runpm=0`** —
  [amdgpu-runpm-durandal.nix](../../flake/modules/nireHost/durandal/fixes/amdgpu-runpm-durandal.nix),
  added 2026-09-14. Unproven hypothesis aimed at the D0-across-S3 suspicion.
  Revert by deleting the file.
- **[suspend-probe-durandal.nix](../../flake/modules/nireHost/durandal/fixes/suspend-probe-durandal.nix)**
  — dumps wakeup, GPE and drive state to `/var/log/suspend-probe/` around every
  suspend, `sync`'d so it survives the power cut. `/var/log` is its own btrfs
  subvolume, outside the wiped root.

## Progress

**All live since the 2026-09-14 02:24 reboot**: the probe (2026-09-13), plus
`amdgpu.runpm=0` and smartmontools from
[#320](https://github.com/NireBryce/nixos-configs/pull/320). Confirmed in
`/proc/cmdline` and `/sys/module/amdgpu/parameters/runpm`. The power-cycle
detector has still never run against a real hang, so the first one tests the
detector as much as the machine — and the first dump only sets the per-drive
baseline, since the counters are cumulative.

**Confounded from the 2026-09-14 02:24 reboot on.** That reboot made
`amdgpu.runpm=0` live *and* moved the kernel 6.18.43 → 6.18.51, the latter
arriving with a `flake.lock` update rather than deliberately. Two variables, one
change. It only matters if the hangs **stop** — then the cause is unattributable
between the two, and booting the previous generation once is what separates
them. If hangs continue, neither worked and the confound is moot.

Cycles, all 2026-09-14 UTC. Outcomes are Elly's — nothing in the dumps yet
separates a hang from a clean resume:

| # | window | mode | trigger | slept | outcome |
|---|---|---|---|---|---|
| 1 | 03:21→03:44 | s2idle | auto | 23 m | **hang** — SMU `-ETIME`, cold boot, RAM lost |
| 2 | 03:52→04:20 | deep | auto | 29 m | **hang** — PSU race, RAM kept |
| 3 | 04:28→04:29 | deep | auto | 70 s | **hang** — PSU race, RAM kept |
| 4 | 04:34→04:46 | deep | auto | 11 m | clean, woke on keyboard |
| 5 | 04:54→04:55 | deep | auto | 21 s | clean |
| 6 | 05:07→05:57 | deep | **manual** | 50 m | clean |

Three hangs in six, all on auto-suspend; the one manual cycle was clean. Too
few to call auto-vs-manual settled, and cycles 4 and 5 show auto succeeding.
Only cycle 1 was visible to `suspend_stats`.

## Reading the dumps

**Pair files by order, not timestamp** — `pre` is stamped at suspend and `post`
at resume, so a pair never shares a stamp.

`## requester` labels the cycle auto or manual. `## drive power cycles` is the
only in-band evidence of a no-wake hang: recovering from one means cutting PSU
power, and the drives count that. **A cycle where the count moves is a cycle
that hung.** Added 2026-09-14 and not yet observed across a real hang.

## See also

- [hosts.md](../hosts.md) — the host roster.
- [lessons-learned.md](../lessons-learned.md) — the KDE hybrid-sleep trap, a
  different suspend failure on this fleet.
