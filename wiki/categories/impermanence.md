# `impermanence` — `nire/impermanence/`

## Contents

- [What's in it](#whats-in-it)
- [Imported by](#imported-by)
- [The other "impermanence" — don't confuse the two](#the-other-impermanence--dont-confuse-the-two)
- [Reaching the home-manager side](#reaching-the-home-manager-side)
- [See also](#see-also)

**Read `WARN-impermanence.nix` itself before changing anything here — this
page is an index, not a substitute.** See
[../impermanence-and-secrets.md](../impermanence-and-secrets.md) for the
cross-cutting version of this topic (which hosts wipe `/root`, the initrd
sharp edges); this page is specifically about what lives in the category
directory.

## What's in it

- **`root-rollback/WARN-impermanence.nix`** — the module. Deletes the `/root`
  btrfs subvolume in initrd on every boot and snapshots a fresh one from
  `root-blank`. 532 lines; the file itself is the documentation for the
  mechanics (systemd-cryptsetup unit naming, ordering, the persisted
  directories list). Its own name is deliberately alarming, and per its own
  header comment, even the module's *name* is load-bearing: rename the file
  and anything importing it by literal name breaks silently, though category
  membership itself survives a rename (both are keyed off the same
  filename).
- **`root-rollback/kde-sleepmode.nix`** — the desktop half of `nohibernate`.
  `WARN-impermanence.nix` sets `nohibernate` and disables hybrid
  sleep/hibernation at the systemd level, because a host that wipes `/root`
  on boot cannot survive resuming an image that predates the wipe. PowerDevil
  (KDE's power daemon) doesn't degrade gracefully when told
  `CanHybridSleep=no` — it drops the suspend request entirely rather than
  falling back to plain suspend, which broke suspend outright on 2026-08-10
  (`lessons-learned.md` §30). This module is the other half of that same
  decision; the two have to agree or the machine can't sleep at all. It's
  `homeManager`-class and applies to **both** Linux desktop hosts durandal
  and tenacity, since durandal also imports `boot`/`impermanence` and would
  hit the identical PowerDevil failure otherwise.
- **`_disko/impermanence-luks-btrfs.nix`** — a reusable disko generator
  reproducing durandal/tenacity's hand-run LUKS + btrfs layout. Under a
  `_`-prefixed directory so `import-tree` ignores it; not a flake-parts
  module but a curried function returning a normal `nixosModule`. **Nothing
  imports this today** — see
  [../flake/doc/disko-impermanence-layout.md](<../../flake/doc/disko-impermanence-layout.md>)
  for what it's for and how to actually wire it in.

## Imported by

`durandal`, `tenacity` — two of the three NixOS hosts, wiping
`/root` on every boot. `nire-cube` does **not** — its real install turned out to be a
plain persistent root, not LUKS+impermanence, a correction made 2026-08-21
after the fact. That absence is why two other things exist:
[`nireUser/elly/user-settings/WARN-password-required.nix`](elly.md), which
warns that a non-impermanence host has no login-password-setting help
anywhere in this repo, and
`nire/system/impermanence/declare-persistence-option.nix` (see
[system](system.md)) — a **different, easily confused file** in a
similarly-named-but-different location.

## The other "impermanence" — don't confuse the two

`nire/system/impermanence/declare-persistence-option.nix` is **not** part of
this category. It's a subdirectory of `nire/system/` that happens to share
the word "impermanence" in its path, collected into the `system` category
aggregate like everything else under `nire/system/`, not into this one. It
declares the `environment.persistence` *option* (not any actual persisted
paths) for every NixOS host unconditionally — including `cube`, which
doesn't wipe anything — specifically so that `tailscale-persist.nix`,
`jovian-persist.nix`, and friends can write to
`environment.persistence."/persist"` without erroring on a host that never
imported this category. Two different directories, two different purposes,
one shared word — see that file's own header (quoted in full on
[system](system.md)) for why `lib.mkIf` alone can't do this job: the module
system validates config structure against declared options before `mkIf`'s
condition is ever resolved, so the option has to exist unconditionally even
though the *value* doesn't.

## Reaching the home-manager side

Only `kde-sleepmode.nix` is `homeManager`-class; the rest of this category
is `nixos`-class and doesn't reach Home Manager. It rides into every host
via `nireUser/elly-home-manager.nix` (the shared `ellyHomeManager` bundle,
outside every category tree — see [../architecture.md](../architecture.md)),
not through each host's own per-host imports list.

## See also

- [../disk-formatting.md](../disk-formatting.md) — the runbook: what to
  decide and do to actually get a new host onto this layout, as opposed to
  what's in the category once it does.
- [../impermanence-and-secrets.md](../impermanence-and-secrets.md) — the
  cross-cutting topic page.
- [system](system.md) — for `declare-persistence-option.nix` and the
  `*-persist.nix` sibling-file convention.
- [virtualization](virtualization.md), [desktop-env](desktop-env.md) — two
  more categories with their own `*-persist.nix` files following the same
  convention.
