# 28. A guard keyed on a signal that never fires is worse than no guard

_Last modified: 2026-09-29_

§28 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §28's full account.

Moving the rollback to systemd stage 1 dropped the safety `postResumeCommands`
had for free: it ran *after* the resume attempt, so a hibernation resume skipped
the wipe. The name carried the guarantee.

The replacement, `ConditionKernelCommandLine = [ "!resume" ]`, cannot fire.
systemd does not need `resume=` on the command line —
`systemd-gpt-auto-generator` finds the swap partition by GPT type and sets
`/sys/power/resume` itself, which it had already done.

It was justified in a comment reading "tenacity has no swap", taken from
`swapDevices = [ ]`. The machine had 20G on `nvme0n1p6` the whole time. §2 and
§24, in the module that deletes `/root`, the same day as §24.

Hibernation is now off at the kernel level, which removes the hazard instead of
testing for it. **A condition is a claim about the world; check it fires on the
machine before trusting it to prevent something.**
