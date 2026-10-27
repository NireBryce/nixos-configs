# `homelab` — `homelab-config/homelab/`

_Last modified: 2026-10-22_

## Contents

- [Category contents](#category-contents)
- [Nested categories overlap their parents on purpose](#nested-categories-overlap-their-parents-on-purpose)
- [Why one category for all the services](#why-one-category-for-all-the-services)
- [Imported by](#imported-by)
- [See also](#see-also)

## Category contents

Nothing of its own — it's an umbrella. Added 2026-08-27, folding six
existing, previously-standalone categories under one directory:
[containers](containers.md), [git-forge](git-forge.md),
[monitoring](monitoring.md),
[reverse-proxy](reverse-proxy.md), [shortlinks](shortlinks.md), and
[virtualization](virtualization.md). Each is still a category of its own,
addressable by its own name (each holds a subfolder of modules) — this page
doesn't repeat their content, see each one's own article for what it
contains and why it's shaped the way it is.

A later one, [backup](backup.md), joined 2026-08-28 the same way — restic,
backing up the state the other services produce to the `ts-hive` NAS already on the
network. It's the odd one out functionally (nothing to reach over the
tailnet, no port, no Caddy route — a timer, not a listener) but structurally
identical: its own category, `homelab-config/homelab/backup/`, cube-only,
folded in by the same nesting this page describes below.

## Nested categories overlap their parents on purpose

Same mechanism [hardware](hardware.md) documents for `hardware-config/hardware/amd/`:
`homelab` includes each nested category by name rather than re-deriving
their modules ([module-files.md](../module-files.md)), giving one coarse
handle (`homelab`, what cube includes) and fine ones that stay individually
includable — a host can take one child, e.g. `containers`, without the rest
(tenacity did exactly that until it dropped podman 2026-09-26). This is
load-bearing, not a bug.

**A behavioral consequence, since removed:** until 2026-09-28 a category
skipped the files sitting directly in its own directory, so `homelab`'s
collector had to add a nested category's such files back itself
(`bareModulesOf`). Plain delegation once silently dropped exactly such a
file from cube (`virtualization-cube.nix`, then the `nire-llm-sandbox`
wiring), caught by evaluating `config.systemd.services` before and after.
The rule and `bareModulesOf` are both gone — `flake/doc/dirsAsCategory.md`'s
History has the account.

## Why one category for all the services

Four ([monitoring](monitoring.md), [git-forge](git-forge.md),
[shortlinks](shortlinks.md), [reverse-proxy](reverse-proxy.md))
were cube-only from birth; `virtualization` and
[containers](containers.md) became effectively cube-only when durandal
dropped both 2026-08-27. By then `cube-configuration.nix` carried eight
import lines for self-hosted services alone; folding them into one
`homelab` import collapses that to a single line. The per-service mechanism
notes still live on each service's own module header and wiki page.

## Imported by

`nire-cube` only, as `homelab` (replacing separate per-service import lines). No
other host imports it, or should — everything under it was cube-only before
the move and stays so.

## See also

- [../architecture.md](../architecture.md) — the category mechanism
  generally, and the "Related, and a live trap" note on `virtualization`/
  `containers` history.
- [00-INDEX.md](00-INDEX.md) — the full category index and table.
- [../hosts.md](../hosts.md) — `nire-cube`'s full host page.
