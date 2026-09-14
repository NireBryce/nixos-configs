{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "Disable amdgpu runtime PM on durandal, testing a fix for the S3 no-wake hang";

            # UNPROVEN, added 2026-09-14. This is a hypothesis under test, not a
            # known fix -- if it is still here in a month with no verdict recorded
            # in wiki/experiments/durandal-auto-suspend-hang.md, that page is the
            # thing to fix, not this file.
            #
            # durandal suspends into S3 and then cannot be woken by anything --
            # keyboard, power button, network -- until power is physically removed
            # at the PSU, which resets the GPU while DRAM stays alive on standby.
            # Three of the first four instrumented cycles failed this way.
            #
            # Measured 2026-09-14, and this is the fact that picks this parameter:
            # across a boot's worth of cycles, CLOCK_BOOTTIME minus CLOCK_MONOTONIC
            # accounted for essentially the whole pre-to-post window (2473.6s of
            # 2491s, the 17s remainder being ordinary device suspend/resume
            # overhead across three cycles). So during a hang the CPU is NOT
            # running -- the machine is genuinely in S3 and will not come out. It
            # is not a kernel wedge partway through resume, which is what the
            # identical resume logs had suggested.
            #
            # The standing suspect is that the card never leaves D0. Every single
            # suspend, on every boot going back to July, logs
            #
            #     amdgpu 0000:07:00.0: amdgpu: MODE1 reset
            #     amdgpu 0000:07:00.0: Refused to change power state from D0 to D3hot
            #
            # A Navi 22 (1002:73df) held in D0 across S3 is a known way to end up
            # unable to resume. runpm=0 disables amdgpu's runtime power management,
            # which is the usual first move for that class of failure.
            #
            # Once caught with the kernel watching: resume of IP block <smu> failed
            # -62 (-ETIME), last_failed_dev 0000:07:00.0. That one was recorded in
            # /sys/power/suspend_stats only because the SMU timeout happened inside
            # a resume the kernel was awake for; the no-wake variant is invisible
            # from inside the OS by construction, since nothing is executing.
            #
            # NOT a BIOS regression: it predates F21c on Elly's own account
            # (2026-09-14). An earlier pass here tried to pin it on the F18d ->
            # F21c flash from journal counts and the sample could not support it --
            # 0 failures in 27 suspends under F18d is ~46% likely at the observed
            # rate even if nothing changed.
            #
            # To reverse: delete this file. To tell whether it worked, the probe in
            # this directory records drive power-cycle counts -- a cycle where they
            # increment is one that was recovered by cutting power, i.e. a hang.
            boot.kernelParams = [ "amdgpu.runpm=0" ];
        };
}
