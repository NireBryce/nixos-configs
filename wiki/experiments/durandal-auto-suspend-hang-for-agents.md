# Auto-suspend hang on nire-durandal, for agents

_Last modified: 2026-09-14_

Condensed from
[durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md), which keeps the
reasoning and the cycle log. **Status: mechanism partly identified, cause
not. Nothing under test — `amdgpu.runpm=0` was tried 2026-09-14 and failed.**

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
- **Auto vs manual is NOT the discriminator.** Both hang; a manual cycle hung
  2026-09-14. An early 35-suspend requester tally made auto look causal.
- **"A `pre` with no `post` is a hang" is WRONG.** `powerDownCommands` fires on
  shutdown too, so every reboot leaves an orphan `pre`. Use the power-cycle
  delta.

## Ruled out

**`amdgpu.runpm=0`** (tried and removed 2026-09-14; hung with it active, and
it did not change the `D0 to D3hot` refusal it targeted) ·
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

## Reading the dumps

- `## requester` — `org_kde_powerdevil` = idle timeout (auto);
  `plasmashell` / `kscreenlocker` = a person asked.
- `## drive power cycles` — **count moves = that cycle hung**, since recovery
  means cutting PSU power. Only in-band evidence of the no-wake shape.
  **Validated 2026-09-14**: `nvme0` 2854→2857, `sda` 6162→6165 over one 58 s
  window (three cuts). Counters are cumulative — only deltas carry signal.

## See also

[durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md) ·
[hosts.md](../hosts.md) · [lessons-learned.md](../lessons-learned.md)
