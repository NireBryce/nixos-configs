{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }:
            let
                probe = phase: ''
                    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.systemd ]}:$PATH

                    dir=/var/log/suspend-probe
                    mkdir -p "$dir" || exit 0
                    out="$dir/$(date -u +%Y%m%dT%H%M%SZ)-${phase}.txt"

                    {
                        echo "# phase   ${phase}"
                        echo "# date    $(date -Is)"
                        echo "# uptime  $(cut -d' ' -f1 /proc/uptime)s"
                        echo "# kernel  $(uname -r)"
                        echo

                        # Labels this cycle auto vs manual without needing the journal
                        # later: org_kde_powerdevil means the idle timeout fired,
                        # plasmashell/kscreenlocker mean a person asked.
                        echo "## requester"
                        timeout 5 journalctl -b 0 -u systemd-logind -n 200 --no-pager -o short-iso 2>/dev/null \
                            | grep "suspend requested from client" | tail -1
                        echo

                        echo "## sleep mode"
                        cat /sys/power/mem_sleep 2>/dev/null
                        echo

                        echo "## suspend_stats"
                        for f in /sys/power/suspend_stats/*; do
                            printf '%s = %s\n' "$(basename "$f")" "$(cat "$f" 2>/dev/null)"
                        done
                        echo

                        echo "## /proc/acpi/wakeup"
                        cat /proc/acpi/wakeup 2>/dev/null
                        echo

                        echo "## ACPI GPE counters (nonzero only)"
                        for f in /sys/firmware/acpi/interrupts/*; do
                            read -r n rest < "$f" 2>/dev/null || continue
                            [ "$n" = "0" ] && continue
                            printf '%-12s %8s  %s\n' "$(basename "$f")" "$n" "$rest"
                        done
                        echo

                        echo "## PCI wakeup + power state"
                        for d in /sys/bus/pci/devices/*; do
                            w=$(cat "$d/power/wakeup" 2>/dev/null) || continue
                            printf '%s  %-8s state=%-8s count=%s active=%s\n' \
                                "$(basename "$d")" "$w" \
                                "$(cat "$d/power_state" 2>/dev/null)" \
                                "$(cat "$d/power/wakeup_count" 2>/dev/null)" \
                                "$(cat "$d/power/wakeup_active_count" 2>/dev/null)"
                        done
                        echo

                        echo "## USB wakeup"
                        for d in /sys/bus/usb/devices/*; do
                            w=$(cat "$d/power/wakeup" 2>/dev/null) || continue
                            [ -z "$w" ] && continue
                            printf '%-10s %-8s %s\n' \
                                "$(basename "$d")" "$w" "$(cat "$d/product" 2>/dev/null)"
                        done
                        echo

                        echo "## /sys/class/wakeup"
                        for w in /sys/class/wakeup/*; do
                            printf '%-14s %-18s event=%-8s active=%s\n' \
                                "$(basename "$w")" \
                                "$(cat "$w/name" 2>/dev/null)" \
                                "$(cat "$w/event_count" 2>/dev/null)" \
                                "$(cat "$w/active_count" 2>/dev/null)"
                        done
                    } > "$out" 2>&1

                    # The whole point: the machine may lose power before anything
                    # else reaches disk, so flush before handing off to the kernel.
                    sync

                    # Two files per cycle; keep the window bounded.
                    ls -1t "$dir" 2>/dev/null | tail -n +201 | while read -r old; do
                        rm -f "$dir/$old"
                    done

                    true
                '';
            in {
                # # description = "Dump wakeup/GPE state around every suspend on durandal, to survive a hang";

                # nire-durandal hangs on auto-suspend (PowerDevil's idle timeout) but
                # suspends fine when a person asks -- confirmed 2026-09-13 by labelling
                # all 35 suspends of the current boot by logind requester:
                #
                #     org_kde_powerdevil   13   idle timeout   <- hangs
                #     plasmashell          15   menu           ok
                #     kscreenlocker         7   lock screen    ok
                #
                # and the 13 PowerDevil ones are exactly the 13 preceded, one second
                # earlier, by org.kde.powerdevil.wakeupsourcehelper. Recovery is a PSU
                # power-cycle timed to reset the wedged device while DRAM stays alive on
                # standby, so the hang destroys its own evidence: journald never writes,
                # /sys/power/suspend_stats reports 35 success / 0 fail, and a hang that
                # gets power-cycled the next morning is indistinguishable in the journal
                # from an ordinary overnight sleep.
                #
                # Hence dumping to disk with an explicit sync instead of logging. Runs
                # via powerManagement rather than a hand-written /etc/systemd/system-sleep
                # hook because sleep-actions is already ordered `before sleep.target`
                # (nixpkgs nixos/modules/config/power-management.nix) -- after the
                # wakeupsourcehelper, last scripted point before the kernel suspends.
                # powerUpCommands is deprecated for removal in 26.11; these two are not.
                #
                # Reads the pre/post pair to answer: does the helper change wakeup state
                # on auto-suspend only? A `pre` file with no matching `post` is a cycle
                # that never came back on its own.
                #
                # Deliberately cannot fail the suspend: no `set -e`, every read tolerates
                # absence, journalctl is bounded by `timeout`, and the script ends `true`.
                #
                # Diagnostic, not a fix. b550-suspend-fix.nix in this directory is the
                # actual wakeup fix and is unrelated to the hang.
                powerManagement.powerDownCommands = probe "pre";
                powerManagement.resumeCommands    = probe "post";
            };
}
