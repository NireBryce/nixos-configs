# Auto-suspend hang on nire-durandal

_Last modified: 2026-09-13_

`nire-durandal` hangs when PowerDevil's idle timeout suspends it, and suspends
normally when a person asks. **Status: instrumented and under test, not
diagnosed** — nothing on this page is a fix, and the mechanism is still
unknown. What it records is the evidence gathered on 2026-09-13, what that
evidence rules out, and what is currently running to catch the failure.

## Contents

- [Symptom](#symptom)
- [What is established](#what-is-established)
- [Ruled out](#ruled-out)
- [Under test](#under-test)
- [Reading the dumps](#reading-the-dumps)
- [Not the b550 wakeup fix](#not-the-b550-wakeup-fix)
- [See also](#see-also)

## Symptom

This is not a spurious wake. The machine does not come back on its own — it
wedges during the transition and needs power physically removed at the PSU,
timed to drop the stuck device while DRAM stays alive on standby. Held off too
long, the RAM contents go and the session with them.

## What is established

All 35 suspends of the boot beginning 2026-08-22, labelled by `logind`
requester:

| requester | count | trigger | outcome |
|---|---|---|---|
| `org_kde_powerdevil` | 13 | idle timeout | hangs |
| `plasmashell` | 15 | menu | fine |
| `kscreenlocker` | 7 | lock screen | fine |

The 13 PowerDevil suspends are exactly the 13 preceded, one second earlier, by
`org.kde.powerdevil.wakeupsourcehelper`. No manual suspend invokes it.

Logs cannot see the hang. journald never writes, `/sys/power/suspend_stats`
reports 35 success / 0 fail, and a hang that gets power-cycled the next morning
is indistinguishable in the journal from an ordinary overnight sleep. Duration
analysis therefore proves nothing either way.

## Ruled out

- **Resizable BAR** — off. BAR0 on the GPU is 256 MB.
- **amdgpu memory eviction** (upstream `drm/amd: Fail the suspend if resources
  can't be evicted`) — zero occurrences, and 27 GB of swap is present, so the
  precondition does not hold.
- **amdgpu ring timeouts, reset failures, VM faults** — zero across four boots
  back to July.
- **`Refused to change power state from D0 to D3hot` + `MODE1 reset`** — fires
  on 100% of suspends in every boot. Normal BACO behaviour for this card (Navi
  22, `1002:73df`), not a discriminator. An earlier pass flagged these lines as
  significant and it was a dead end.
- **The BIOS update, as a cause of spurious wakes** — F18d → F21c, flashed
  2026-08-22; the short-sleep rate is ~3% either side of it. That measures
  *wakes*, not hangs, so it does **not** clear F21c of causing this.

## Under test

- **s2idle instead of S3.** Set live 2026-09-13 via
  `echo s2idle > /sys/power/mem_sleep`. **Reverts on reboot** — not in config.
- **[suspend-probe-durandal.nix](../../flake/modules/nireHost/durandal/fixes/suspend-probe-durandal.nix)**
  — dumps wakeup and GPE state to `/var/log/suspend-probe/` before suspend and
  after resume, with an explicit `sync` so it survives the power cut. `/var/log`
  is its own btrfs subvolume, outside the wiped root. Switched 2026-09-13.

## Reading the dumps

A `-pre` with a matching `-post` is a cycle that completed on its own. **A
`-pre` with no `-post` is the hang, captured** — the first direct evidence of
it, since nothing else survives.

Each file's `## requester` section labels the cycle auto or manual without
needing the journal; `## sleep mode` records whether it ran s2idle or deep.

`diff` a pre against its post to settle whether `wakeupsourcehelper` changes
wakeup state on auto-suspend but not on manual.

## Not the b550 wakeup fix

[b550-suspend-fix.nix](../../flake/modules/nireHost/durandal/fixes/b550-suspend-fix.nix)
is unrelated and intact — both `1022:1483` bridges read `disabled`.

One unapplied finding from the same investigation: `PTXH` (`01:00.0`,
`1022:43ee`, the 500-series xHCI) is the only device on the machine with any
wakeup activity — 32 events, matching `gpe08` and `sci` exactly, over 23 days.
Disabling it would cost wake-on-keyboard, as the Moonlander sits on that
controller while the mouse does not. Parked deliberately: it addresses wake
sources, and this page is about a hang.

## See also

- [hosts.md](../hosts.md) — the host roster and what each machine is.
- [lessons-learned.md](../lessons-learned.md) — including the KDE hybrid-sleep
  trap, a different suspend failure on this fleet.
