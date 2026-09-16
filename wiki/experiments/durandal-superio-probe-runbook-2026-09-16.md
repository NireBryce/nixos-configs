# Superio rail probe on durandal, as run on 2026-09-16

_Last modified: 2026-09-16_

**This page rots within a day of being written, and is kept only as a
historical record of what was done on 2026-09-16.** It is a transcript of a
one-off hand procedure, not current instructions. The store path below is
pinned to kernel 6.18.51 and stops existing at the next kernel bump; the module
is hand-loaded and gone at the next reboot. Do not follow this page expecting
it to work — read it to see what was tried and what came back.

The durable version of these findings lives on
[durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md). If the two ever
disagree, that page wins and this one is wrong.

## Contents

- [Why this was run](#why-this-was-run)
- [What was run](#what-was-run)
- [What came back](#what-came-back)
- [What it ruled out, and what it did not](#what-it-ruled-out-and-what-it-did-not)
- [See also](#see-also)
## Why this was run

The auto-suspend hang predates Linux (Elly recalls it under Windows while
dual-booting), so the suspicion on 2026-09-16 was firmware or wear rather than
driver. The B550M DS3H's IT8688E superio exposes **VBAT** and the **3VSB**
standby rail — the rail holding DRAM alive through S3 and through the PSU
power-cut that recovers a hang. Nothing else on the machine can read them.

## What was run

Neither parameter is optional. Without `ignore_resource_conflict=1` the load
fails outright; without `update_vbat=1` Vbat reports the stale power-up value
rather than a live one.

```sh
nix build --no-link --print-out-paths \
  '.#nixosConfigurations.nire-durandal.config.boot.kernelPackages.it87'
sudo modprobe hwmon-vid
sudo insmod <that store path>/lib/modules/6.18.51/kernel/drivers/hwmon/it87.ko \
  ignore_resource_conflict=1 update_vbat=1
sensors
```

`modprobe it87` is **wrong** and was avoided: it resolves against
`/lib/modules` and loads the in-tree driver, whose chip list stops at `it8795`
and does not include this board's chip. `insmod` by explicit store path is the
only way to reach the out-of-tree build, and it does not resolve the
`hwmon-vid` dependency for you.

Undo: [`undo-superio-sensors-b550-hypothesis-monitoring.sh`](../../flake/scripts/undo-superio-sensors-b550-hypothesis-monitoring.sh).

## What came back

`Found IT8688E chip at 0xa40, revision 1` — the chip was previously only
inferred from the board model.

| reading | value | confidence |
|---|---|---|
| `3VSB` | 3.26 V | trusted — internal to the superio, correctly scaled |
| `Vbat` | 3.19 V | trusted — same, and live thanks to `update_vbat=1` |
| `+12V` | 12.18 V | trusted — Vision-D ratio ×6.000, +1.5% off nominal |
| `+5V` | 5.01 V | trusted — Vision-D ratio ×2.500, 0.0% off nominal |
| `+3.3V` | 2.06 V raw | **NOT trusted** — ×1.680 gives 3.46 V, 4.9% high, and disagrees with 3VSB by 0.20 V |

Ratios and labels were borrowed from `GA-B550-VISION-D.conf` and
`GA-B550M-AORUS-PRO.conf` — both rev 1.0, **neither of them this board**. No
upstream config exists for the B550M DS3H at any revision. They are believed
right for `+12V`/`+5V` only because they land on nominal, not because of
provenance; none of it was checked against BIOS or a meter.

## What it ruled out, and what it did not

**Ruled out:** a dying CMOS battery, and gross standby-rail failure.

**Not ruled out:** the wear hypothesis generally. Every number above was
sampled while the machine was **awake**. The failure happens in S3 at a far
lower load, and nothing can sample while the CPU is off — a supply that
regulates fine at desktop idle can still misbehave there. PSU substitution
remains the only decisive test, and was not performed.

## See also

- [durandal-auto-suspend-hang.md](durandal-auto-suspend-hang.md) — the durable
  findings; this page is the transcript behind them.
