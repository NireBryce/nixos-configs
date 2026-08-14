# Re-enable the IOMMU that Jovian turns off, because this is not a Steam Deck.
#
# CONFIRMED FIX, 2026-08-12. Suspend went from 0% to 92.5% hardware sleep
# residency on the first boot with this applied -- evidence at the bottom.
#
# Jovian sets `amd_iommu=off` in modules/steamos/boot.nix, copied verbatim from
# Valve's grub-steamos defaults in jupiter-hw-support. That is Steam Deck
# tuning: Van Gogh silicon, which has no NPU, so switching the IOMMU off costs
# nothing there. tenacity is a GPD G1617-02-L -- Ryzen 7 8840U, Phoenix, which
# DOES have an XDNA NPU at 0000:c4:00.1. amd-s2idle reports:
#
#     ❌ NPU is not supported with IOMMU disabled
#     🚫 Your system does not meet s2idle prerequisites!
#
# and that is the only substantive prerequisite failure it finds (the other two
# ❌ are its own blind spots -- cpuid/msr modules not loaded).
#
# What is actually wrong, measured 2026-08-12 with amd-s2idle test --force:
#
#     Duration 1:05 | Hardware Sleep 0.00% | Average Power 23.65W | Battery -1%
#     "System had low hardware sleep residency"
#
# 23.65W asleep is active-load power with the screen off, which is why the fan
# stays on and why the thing is warm and flat after sitting on a shelf. Every
# suspend since this branch booted has logged `amd_pmc: Last suspend didn't
# reach deepest state` with /sys/power/suspend_stats/last_hw_sleep at 0. There
# is no S3 to fall back to -- /sys/power/mem_sleep offers only [s2idle] -- so
# s0i3 has to be made to work rather than avoided.
#
# enableDefaultCmdlineConfig gates exactly one mkIf block, which sets only
# boot.kernelParams (checked in Jovian's source), so turning it off and
# re-declaring the list costs nothing else. Every other param below is Valve's,
# copied unchanged, with their reasoning left at the reference rather than
# duplicated here.
#
# RESULT, first boot with this applied:
#
#     last_hw_sleep   59,213,866 us  = 59.2s
#     sleep cycle     01:37:27 -> 01:38:31 = 64s      -> 92.5% residency
#     "Last suspend didn't reach deepest state"       -> 0 occurrences
#
# from /sys/power/suspend_stats and the journal, not from the tool. amd-s2idle
# itself reports this as "8939.39%", which is its own arithmetic bug -- it is
# off by exactly 100x (59.2s rendered as 5900s). Read the kernel counter, not
# that percentage, when checking this again.
#
# So the IOMMU was the blocker, and the NPU prerequisite amd-s2idle flagged was
# pointing at the real cause even though it never named a blocking device. Two
# other suspects were noted while diagnosing and turned out NOT to be needed --
# recorded here so nobody re-investigates them: the EC fired gpe0A 187 times
# during a 65-second sleep (`ACPI: EC: GPE=0xa`), and the USB4 bridge at
# 00:08.3 carries a kernel quirk "disabling D3cold for suspend". Both were
# present on the fixed boot too.
#
# The touchscreen fix in this directory is a separate bug and was never
# implicated in this one: it cut wake events during sleep from 71 to 1, which
# is its own win.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            jovian.steamos.enableDefaultCmdlineConfig = false;

            # Valve's list from jupiter-hw-support's grub-steamos, minus
            # amd_iommu=off. See Jovian's modules/steamos/boot.nix for the
            # per-parameter reasoning.
            boot.kernelParams = [
                "log_buf_len=4M"
                "amdgpu.lockup_timeout=5000,10000,10000,5000"
                "ttm.pages_min=2097152"
                "amdgpu.sched_hw_submission=4"
                "amdgpu.dcdebugmask=0x20000"
                "audit=0"
            ];
        };
}
