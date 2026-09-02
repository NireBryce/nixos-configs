# `homelab` — `nire/homelab/`

## Contents

- [What's in it](#whats-in-it)
- [Nested categories overlap their parents on purpose](#nested-categories-overlap-their-parents-on-purpose)
- [Why one category for all seven](#why-one-category-for-all-seven)
- [Imported by](#imported-by)
- [See also](#see-also)

## What's in it

Nothing of its own — it's an umbrella. Added 2026-08-27, folding seven
existing, previously-standalone categories under one directory:
[containers](containers.md), [git-forge](git-forge.md),
[landing](landing.md), [monitoring](monitoring.md),
[reverse-proxy](reverse-proxy.md), [shortlinks](shortlinks.md), and
[virtualization](virtualization.md). Each kept its own `dirsAsCategory.nix`,
so each is still its own aggregate, addressable by its own name — this page
doesn't repeat their content, see each one's own article for what it
actually contains and why it's shaped the way it is.

An eighth, [backup](backup.md), joined 2026-08-28 the same way — restic,
backing up the state the other seven produce to the QNAP NAS already on the
network. It's the odd one out functionally (nothing to reach over the
tailnet, no port, no Caddy route — a timer, not a listener) but structurally
identical: its own `dirsAsCategory.nix` under `nire/homelab/backup/`,
cube-only, folded in by the same delegation this page describes below.

## Nested categories overlap their parents on purpose

Same mechanism [hardware](hardware.md) documents for `nire/hardware/amd/`:
`homelab`'s `dirsAsCategory.nix` references each nested category by name
(via `modules/_lib/category-collector.nix` — see that doc's History
section) rather than re-deriving their modules, giving one coarse handle
(`homelab`, what cube imports) and fine ones that stay individually
importable (`tenacity` imports `containers` and must not get the rest).
`flake/doc/dirsAsCategory.md` documents this as load-bearing, not a bug.

**One real behavioral consequence:** the collector explicitly re-collects a
nested category's own *bare* files (sitting directly in its root, which
that category's own aggregate excludes) alongside delegating to its
aggregate — `bareModulesOf` in `category-collector.nix`. Plain delegation
once silently dropped exactly such a file (`virtualization-cube.nix`, the
`nire-llm-sandbox` wiring, both since removed): `homelab` only got what
`virtualization`'s own aggregate included, and that deliberately excludes
bare files. Confirmed by evaluating `config.systemd.services` before and
after, not reasoned about. The mechanism is live but currently unexercised —
see
[virtualization.md](virtualization.md#vms_liblibvirt-vmnix--a-generator-not-a-category-member).

## Why one category for all seven

Five ([monitoring](monitoring.md), [git-forge](git-forge.md),
[shortlinks](shortlinks.md), [reverse-proxy](reverse-proxy.md),
[landing](landing.md)) were cube-only from birth; `virtualization` and
[containers](containers.md) became effectively cube-only when durandal
dropped both 2026-08-27. By then `cube-configuration.nix` carried eight
import lines for self-hosted services alone; folding them into one
`homelab` import collapses that to a single line. The per-service mechanism
notes still live on each service's own module header and wiki page.

## Imported by

`nire-cube` only, as `homelab` (replacing eight separate import lines). No
other host imports it, or should — everything under it was cube-only before
the move and stays so.

## See also

- [../architecture.md](../architecture.md) — the `dirsAsCategory` mechanism
  generally, and the "Related, and a live trap" note on `virtualization`/
  `containers` history.
- [README.md](README.md) — the full category index and table.
- [../hosts.md](../hosts.md) — `nire-cube`'s full host page.
