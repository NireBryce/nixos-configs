# Durandal suspend instrumentation: what is running

_Last modified: 2026-09-16_

Every step run against `nire-durandal` for the auto-suspend investigation, what
survives a reboot, and **how to check rather than trust this page**. Each row
carries its own verification command precisely because a "currently active"
list is the kind of claim that rots silently — re-derive, don't believe.

Findings live on [durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md).
This page is only about machine state.

## Contents

- [Check everything at once](#check-everything-at-once)
- [Active](#active)
- [Stale — removed from config but still live](#stale--removed-from-config-but-still-live)
- [Reverted, do not redo](#reverted-do-not-redo)
- [Teardown](#teardown)
- [See also](#see-also)
## Check everything at once

```sh
echo "mem_sleep:      $(cat /sys/power/mem_sleep)"
echo "runpm:          $(grep -o 'amdgpu.runpm=[0-9]' /proc/cmdline || echo absent)"
echo "pm_print_times: $(cat /sys/power/pm_print_times)"
echo "smartctl:       $(command -v smartctl || echo absent)"
echo "it87:           $(grep -c '^it87 ' /proc/modules)"
echo "dumps:          $(ls -1 /var/log/suspend-probe/*.txt 2>/dev/null | wc -l)"
grep -c "GPU state" "$(grep -oE '/nix/store/[a-z0-9]+-unit-script-sleep-actions-start' \
  /run/current-system/etc/systemd/system/sleep-actions.service | head -1)/bin/sleep-actions-start"
```

## Active

| # | what was run | survives reboot | verify |
|---|---|---|---|
| 1 | `just switch` — deploys the probe, writing pre/post dumps to `/var/log/suspend-probe/` | yes, it is config | `ls /var/log/suspend-probe/ \| wc -l` |
| 2 | same switch — `smartmontools`, for drive power-cycle counts | yes | `command -v smartctl` |
| 3 | same switch — requester fix (`timeout 15`, no `-u` filter) | yes | `grep -c 'timeout 15 journalctl' <probe script>` |
| 4 | `sudo modprobe hwmon-vid` then `sudo insmod <store>/it87.ko ignore_resource_conflict=1 update_vbat=1` | **no — gone at reboot** | `grep -c '^it87 ' /proc/modules` |
| 5 | `just switch` 2026-09-16 — GPU state per cycle (DPM levels, link speed, busy%, hwmon) | yes, config | `grep -c "GPU state" <probe script>` |
| 6 | same switch — `pm_print_times=1` via tmpfiles, per-device suspend/resume timings. Took effect immediately, no reboot | yes, config | `cat /sys/power/pm_print_times` |

`/var/log` is its own btrfs subvolume, outside the wiped root, so dumps survive
both the `/root` wipe and a lost PSU race.

## Stale — removed from config but still live

`amdgpu.runpm=0` was removed in
[#357](https://github.com/NireBryce/nixos-configs/pull/357) after it failed to
prevent a hang, but the **running kernel still carries it** — a kernel
parameter needs a switch *and* a reboot to clear. Verify with
`grep -o 'amdgpu.runpm=[0-9]' /proc/cmdline`; absent means cleared. It is a
no-op either way, so this is tidiness, not urgency.

## Reverted, do not redo

- **`echo s2idle > /sys/power/mem_sleep`** — reverted by the 2026-09-14 reboot.
  `mem_sleep` should read `s2idle [deep]`, brackets on `deep`. Ruled out: the
  SMU failure happened *under* s2idle, and this desktop part has no `amd_pmc`
  or `s0i3` path, so it cannot reach hardware sleep at all.

## Teardown

[`undo-superio-sensors-b550-hypothesis-monitoring.sh`](../../flake/scripts/undo-superio-sensors-b550-hypothesis-monitoring.sh)
removes step 4 plus any hand-dropped `/etc/sensors.d` file and manual
`pm_print_times`/`pm_debug_messages` override. **Not run as of 2026-09-16.**
It no-ops when there is nothing to undo, and only asks for root when there is.

Steps 1-3 are config: revert them by removing the module, not with a script.

## See also

- [durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md) — the findings.
- [durandal-superio-probe-runbook-2026-09-16.md](durandal-superio-probe-runbook-2026-09-16.md)
  — transcript of step 4, deliberately short-lived.
