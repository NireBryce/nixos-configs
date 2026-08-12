# Re-enable the IOMMU that Jovian turns off, because this is not a Steam Deck.
#
# THIS IS AN EXPERIMENT, not a confirmed fix. Read the last paragraph before
# assuming it worked.
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
# UNPROVEN: amd-s2idle did NOT name a blocking device -- it reported 0%
# residency without attributing it. This change tests the one prerequisite it
# flagged. If a forced run still shows 0.00% hardware sleep afterwards, the
# IOMMU was not the blocker: revert this file rather than leaving it in on the
# theory that it might be helping, and look next at the EC, which fired gpe0A
# 187 times during a 65-second sleep (`ACPI: EC: GPE=0xa`), or at the USB4/
# Thunderbolt bridge at 00:08.3, which the kernel already quirks with
# "disabling D3cold for suspend".
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
