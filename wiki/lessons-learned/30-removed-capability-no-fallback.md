# 30. Removing a capability does not make its consumers degrade gracefully

_Last modified: 2026-09-29_

§30 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §30's full account.

Hibernation was disabled — `nohibernate`, plus `AllowHibernation`,
`AllowHybridSleep` and `AllowSuspendThenHibernate` off — to stop suspend writing
a 2.3G image and to close the hazard in §28. The comment justifying it said any
such request would "fall back to a plain s2idle suspend".

Nothing performs that fallback. KDE's PowerDevil had `SleepMode=2`
(`HybridSuspend`; the enum is `SuspendToRam = 1, HybridSuspend = 2,
SuspendThenHibernate = 3`). It asked logind for hybrid sleep, logind answered
`CanHybridSleep=no`, and the request was dropped. **Suspend stopped working
entirely**, and the user found it, not me.

The capability was never gone: `CanSuspend` stayed `yes` and `/sys/power/state`
kept offering `freeze mem` throughout. Only the thing being *asked for* was
unavailable, and the caller had no second choice. The fix was one line of KDE
config, not a config change here.

Two rules out of it, and this is the second time in one session for the first
(§29, unbinding `Ctrl-R` under ble.sh leaves the key dead rather than revealing
what was underneath):

- **"It will fall back" is a claim about a specific consumer**, and consumers
  usually have exactly one plan. Name the consumer and check it.
- **When you turn something off, find what was asking for it.** A grep of the
  relevant `~/.config` would have shown `SleepMode=2` before the switch rather
  than after.
