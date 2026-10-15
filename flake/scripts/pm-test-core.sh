#! /usr/bin/env bash
# Run the kernel's suspend self-test at the `core` level in a loop, from the
# durandal suspend investigation (wiki/experiments/durandal-auto-suspend-hang.md,
# "Not done" -> pm_test).
#
#   sudo pm-test-core.sh [CYCLES]        # default 50
#
# With /sys/power/pm_test set to `core`, writing `mem` to /sys/power/state
# runs the whole kernel descent (freeze, device suspend, noirq, offline CPUs,
# syscore) and then resumes after a short delay WITHOUT entering firmware S3.
# The real hangs are past the GPU's suspend_noirq phase and the kernel logs
# nothing, so the only level that adds information is `core`: a clean loop is
# what "the fault is beyond the kernel" predicts (at ~1 hang in 15 real
# cycles, 50 clean cycles are ~97% likely if so); a freeze means the
# kernel's late descent is where it dies.
#
# A freeze leaves no journal. So each cycle's number is written to the log
# and synced BEFORE the suspend; after a hard reset the last line is the
# cycle that hung. The log is in /var/log/suspend-probe/, a btrfs subvolume
# outside the wiped /root.
#
# This bypasses systemd, so the probe's powerDownCommands do not fire and no
# pre/post dumps are written; drive power is not cut at `core`, so the
# power-cycle counters do not move either. pm_test is restored to `none` on
# any exit that runs the trap -- not after a freeze, which is why the level
# is only ever set for the duration of this script and resets on reboot.
#
# PM_TEST_SYS / PM_TEST_LOG / PM_TEST_SKIP_ROOT exist for the fixture test.
set -euo pipefail

sys=${PM_TEST_SYS:-/sys/power}
log=${PM_TEST_LOG:-/var/log/suspend-probe/pm-test-core.log}
cycles=${1:-50}

if [[ ! $cycles =~ ^[1-9][0-9]*$ ]] || (($# > 1)); then
    echo "usage: pm-test-core.sh [CYCLES]" >&2
    exit 2
fi
if [[ -z ${PM_TEST_SKIP_ROOT:-} ]] && ((EUID != 0)); then
    echo "pm-test-core.sh: needs root (it writes /sys/power)" >&2
    exit 1
fi
if [[ ! -e $sys/pm_test ]]; then
    echo "pm-test-core.sh: $sys/pm_test missing (kernel without CONFIG_PM_DEBUG)" >&2
    exit 1
fi
if ! grep -q '\[deep\]' "$sys/mem_sleep"; then
    echo "pm-test-core.sh: mem_sleep is not [deep]: $(cat "$sys/mem_sleep")" >&2
    exit 1
fi

restore() { echo none >"$sys/pm_test"; }
trap restore EXIT

mkdir -p "$(dirname "$log")"
echo "== $(date -Is) start, $cycles cycles, kernel $(uname -r)" >>"$log"
echo core >"$sys/pm_test"

for ((i = 1; i <= cycles; i++)); do
    echo "$(date -Is) cycle $i/$cycles suspending" >>"$log"
    sync
    echo mem >"$sys/state"
    echo "$(date -Is) cycle $i/$cycles resumed" >>"$log"
done

echo "== $(date -Is) done, $cycles/$cycles clean" >>"$log"
# Baseline from the wiki is zero non-zero returns either direction.
bad=$(journalctl -k -b 0 --no-pager -o cat 2>/dev/null |
    grep -cE 'PM: .* returned -?[1-9][0-9]* after' || true)
echo "non-zero device callback returns this boot: $bad"
echo "$cycles cycles completed; log: $log"
