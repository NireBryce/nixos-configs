# amd-s2idle: hardware sleep residency reported 100× too high in generated reports

Written 2026-08-12 against `amd-debug-tools` 0.2.20 (as packaged in nixpkgs
`e4bae1bd10c9c57b2cf517953ab70060a828ee6f`), Python 3.14, on NixOS 26.11.

Paste-ready for <https://github.com/amd/amd_s2idle/issues> (or wherever
`amd-debug-tools` tracks issues). Everything below the "Describe the bug"
heading is the report; the last section is local notes and should be dropped
before filing.

**Not filed. Not to be filed on the strength of this file existing** — per
`CLAUDE.md`, filing outside `NireBryce/nixos-configs` needs Elly saying so
explicitly, in those words, for this specific report.

---

## Describe the bug

`LowHardwareSleepResidency` formats its `percent` argument with Python's `%`
presentation type, which multiplies by 100. Two call sites pass that argument
in different units: `validator.py` passes a fraction (correct), and
`sleep_report.py` passes an already-scaled percentage (wrong). Reports
generated through the second path therefore state a residency 100× too high:

```
The system was asleep for 66, but only spent 8939.39% of this time in a
hardware sleep state.  In sleep cycles that are at least 60 seconds long it's
expected you spend above 90 percent of the cycle in hardware sleep.
```

The real figure for that cycle was **89.39%**. The sentence is self-refuting —
it says the system spent 8939% of the cycle asleep, then says 90% is expected —
which makes an otherwise good report hard to trust at exactly the moment
somebody is trying to tell whether their fix worked.

**The detection is correct; only the printed number is wrong.** Both call sites
compare against their own scale properly, so the failure is raised in the right
circumstances.

**This is invisible until residency is non-zero.** A machine at 0% residency
formats as `0.00%` either way, so the bug only appears once the underlying
platform problem is fixed.

## Steps to reproduce

On a machine with genuinely poor-but-nonzero s0i3 residency (or by injecting a
`hw` value), generate a report:

```console
$ sudo amd-s2idle test --duration 60 --count 1 --force
```

Compare the failure text against the kernel's own counter:

```console
$ cat /sys/power/suspend_stats/last_hw_sleep
59213866                      # µs, i.e. 59.2 s of a ~66 s cycle → 89.39%
```

Observed: `8939.39%`. Expected: `89.39%`.

## Root cause

`amd_debug/failures.py:440-448` — the formatter expects a fraction:

```python
def __init__(self, duration, percent):
    ...
    f"The system was asleep for {duration}, but only spent {percent:.2%} "
```

`amd_debug/validator.py:632-639` — the live `test` path passes a **fraction**,
and thresholds on `0.9`. Correct:

```python
percent = float(hw / userspace_duration.total_seconds())
if userspace_duration.total_seconds() >= 60:
    if percent > 0.9:
        symbol = "✅"
    else:
        symbol = "❌"
        self.failures += [
            LowHardwareSleepResidency(userspace_duration, percent)
        ]
```

`amd_debug/sleep_report.py` — the report path passes a **percentage**, and
thresholds on `90`. The value has already been scaled by `parse_hw_sleep`:

```python
# line 104
def parse_hw_sleep(hw):
    """Parse the hardware sleep value, throwing out garbage values"""
    if hw > 1:
        return 0
    return hw * 100                                    # → 0..100

# line 208
self.df["Hardware Sleep"] = (self.df["hw"] / self.df["Duration"]).apply(
    parse_hw_sleep
)

# line 241, fed from self.df["Hardware Sleep"] (line 247)
self.analyze_duration(index, t0, t1, requested, hw)

# line 148
def analyze_duration(self, index, t0, t1, requested, hw):
    duration = t1 - t0
    if duration.total_seconds() >= 60 and hw < 90:     # 0..100 scale
        failure = LowHardwareSleepResidency(duration.seconds, hw)
```

So `hw` reaches `{percent:.2%}` already multiplied by 100, and is multiplied
again on the way out.

## Suggested fix

Either scale at the call site:

```python
        failure = LowHardwareSleepResidency(duration.seconds, hw / 100)
```

or make the class take a percentage and format it as a plain number, updating
`validator.py` to match. The first is the smaller change; the second removes
the ambiguity that caused this, since the parameter name `percent` currently
means two different things depending on who calls it.

## Additional context

- `capture_hw_sleep` (`validator.py:459-465`) is correct — it converts the
  kernel's microseconds to seconds with `/ 10**6`. The unit confusion is
  entirely downstream.
- The `Hardware Sleep` column in the generated Summary table is rendered from
  `self.df["Hardware Sleep"]` separately and was not observed to be wrong, so a
  single report can contain both the correct value and the 100×-inflated one.
- `parse_hw_sleep`'s `if hw > 1: return 0` guard means a ratio above 1 is
  discarded as garbage before this point, so the inflated value cannot come from
  a bad kernel counter — it is introduced by the formatting.

---

## Local notes — remove before filing

Found on `nire-tenacity` (GPD G1617-02-L, Ryzen 7 8840U) while fixing a real
s0i3 failure: Jovian-NixOS applies Valve's Steam Deck `amd_iommu=off`, which
blocks hardware sleep on Phoenix APUs that have an NPU. That is written up
separately in `2026-08-12-bugreport-jovian-amd-iommu-s0i3.md`.

The sequence matters for anyone reading both: before the fix, `amd-s2idle`
correctly reported `0.00%` residency at 23.65 W, and its NPU/IOMMU prerequisite
check pointed at the real cause. After the fix it reported `8939.39%`, which is
this bug. Actual residency was 92.5% by the kernel counter (59.2 s of a 64 s
cycle) — the report's own 89.39%-before-scaling figure uses its 66 s duration
rather than the kernel's cycle boundaries, which is a separate and much smaller
discrepancy not worth reporting.

The tool was genuinely useful and this should read as a papercut, not a
complaint. Worth checking whether current upstream `main` still has it before
filing — the nixpkgs package is 0.2.20 and may lag.
