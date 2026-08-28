# `homelab` — `nire/homelab/`

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

## Nested categories overlap their parents on purpose

Same mechanism [hardware](hardware.md) already documents for
`nire/hardware/amd/`: `homelab`'s own `dirsAsCategory.nix` references each of
the seven nested categories by name (as of the 2026-08-27 refactor into
`modules/_lib/category-collector.nix` — see that doc's History section)
rather than re-deriving their modules independently, giving a coarse handle
(`homelab`, what `nire-cube` actually imports) and seven fine ones (for
`tenacity`, which still needs `containers` individually and must not
get the rest — see [containers.md](containers.md)) on overlapping content.
`flake/doc/dirsAsCategory.md` documents this as load-bearing, not a bug.
(`durandal` used to be the other consumer of a fine handle here too, for
`virtualization` and `containers` both, until it dropped both on
2026-08-27 — see [virtualization.md](virtualization.md)'s and
[containers.md](containers.md)'s own "Imported by" sections.)

**One real behavioral consequence, not just reorganization:**
`virtualization-cube.nix` (the `nire-llm-sandbox` VM wiring) sits bare in
`nire/homelab/virtualization/`'s own root, which is what keeps it out of
the `virtualization` category's aggregate specifically. `homelab` still
reaches it anyway — not by walking into `virtualization/` independently any
more, but because the collector explicitly re-collects a nested category's
own bare files alongside delegating to its aggregate (`bareModulesOf` in
`category-collector.nix`), specifically so this file wouldn't get lost when
delegation was added. This is harmless in practice (only cube imports
`homelab`, and the VM was already meant to be cube-exclusive) but it is a
real narrowing of a deliberate exclusion, not a no-op move — see
[virtualization.md](virtualization.md#a-cube-only-addition-that-is-deliberately-not-a-category-member)
for the full account.

**This exact file is why `homelab` referencing `virtualization`'s aggregate
had to carry its bare files along explicitly, rather than delegating
outright.** A first version of the 2026-08-27 delegation change did
delegate outright, and silently dropped `libvirt-vm-llm-sandbox` from
`nire-cube`'s `systemd.services` — exactly the file this section is about,
lost because plain delegation means `homelab` only gets what
`virtualization`'s *own* aggregate decided to include, and that deliberately
excludes this one. Confirmed by evaluating `config.systemd.services` before
and after, not just reasoned about. Fixed the same session, not reverted —
`bareModulesOf` is what restores it, verified again afterward with a full
attribute-set diff (`environment.systemPackages`, `systemd.services`,
`users.users`) against the pre-refactor baseline on every host in the repo,
this one included.

## Why one category for all seven

Five of the seven (`monitoring`, `git-forge`, `shortlinks`, `reverse-proxy`,
`landing`) were cube-only from birth, added one at a time between
2026-08-23 and 2026-08-24, each getting its own category for the same
"nothing here belongs on the handhelds" reason (see each page's own
header). The other two, `virtualization` (added 2026-08-21) and
`containers` (added 2026-08-22), started life shared with other hosts —
`virtualization` with durandal, `containers` with all four NixOS hosts —
and only became cube-exclusive-in-practice-on-cube once durandal dropped
both, 2026-08-27 (`tenacity` still imports `containers` on its own; see that
page's "Imported by"). By 2026-08-27 `cube-configuration.nix` listed eight
import lines for self-hosted services alone (the seven categories plus
`virtualization-cube` as a standalone), each with its own explanatory
comment. Folding them into one `homelab` import collapses that to a single
line — the per-service mechanism notes (Tailscale-only reachability, the
category/module name-collision reasons none of `git-forge`/`shortlinks`/
`reverse-proxy`/`landing` are named after their own module, the
`landing`/`reverse-proxy` pairing) still live on each service's own
module header and wiki page, not repeated on the host file or here.

## Imported by

`nire-cube` only, as `homelab` (replacing what used to be eight separate
import lines). No other host imports it, or should — everything under it
was cube-only before this move and stays cube-only now.

## See also

- [../architecture.md](../architecture.md) — the `dirsAsCategory` mechanism
  generally, and the "Related, and a live trap" note on `virtualization`/
  `containers` history.
- [README.md](README.md) — the full category index and table.
- [../hosts.md](../hosts.md) — `nire-cube`'s full host page.
