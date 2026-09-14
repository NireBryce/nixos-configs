# Auto-suspend hang on nire-durandal, for agents

_Last modified: 2026-09-14_

Condensed from
[durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md), which keeps the
reasoning and the cycle log. **Status: mechanism partly identified, cause not.
One UNPROVEN mitigation under test.**

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
- Resume logs for a hang and a clean cycle are byte-identical.

## Ruled out

`wakeupsourcehelper` (no wakeup-state change in pre/post diffs) · **s2idle**
(SMU failure occurred under it; no `amd_pmc`, no `s0i3` on this desktop part,
so it cannot reach hardware sleep and costs near-idle power) · **BIOS** (bug
predates F21c per Elly, 2026-09-14; the journal counts never supported it —
0-in-27 under F18d is ~46% likely at the observed rate) · Resizable BAR (off,
BAR0 256 MB) · amdgpu memory eviction (0, and 27 GB swap present) · ring
timeouts, reset failures, VM faults (0) · PTXH as a rogue wake source (it is
the keyboard wake path; disabling it costs wake-on-keyboard).

## Under test

| what | where | notes |
|---|---|---|
| `amdgpu.runpm=0` | [amdgpu-runpm-durandal.nix](../../flake/modules/nireHost/durandal/fixes/amdgpu-runpm-durandal.nix) | UNPROVEN. Needs a reboot. Revert by deleting the file. |
| state probe | [suspend-probe-durandal.nix](../../flake/modules/nireHost/durandal/fixes/suspend-probe-durandal.nix) | writes `/var/log/suspend-probe/`, `sync`'d; `/var/log` is its own btrfs subvolume, outside the wiped root |

Not live until `just switch`, and the kernel parameter until a reboot.

## Reading the dumps

- `## requester` — `org_kde_powerdevil` = idle timeout (auto);
  `plasmashell` / `kscreenlocker` = a person asked.
- `## drive power cycles` — **count moves = that cycle hung**, since recovery
  means cutting PSU power. Only in-band evidence of the no-wake shape.
  **Not yet observed against a real hang.**

## See also

[durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md) ·
[hosts.md](../hosts.md) · [lessons-learned.md](../lessons-learned.md)
