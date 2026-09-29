# 34. The dangerous name collision is the one where both halves work

_Last modified: 2026-09-29_

§34 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §34's full account.

CLAUDE.md's `boot` story — the `general-config/boot/` category and durandal's
`boot.nix` merging into one name — has an obvious tell: importing a bootloader
got you an impermanence rollback, which is startling enough to investigate.

Moving the VM modules into a category directory of their own set up the same
collision in a shape with no tell. The directory would have been
`nire/virtualization/`, so `dirsAsCategory` would declare
`flake.modules.nixos.virtualization`; the file inside it was `virtualization.nix`,
which declares `flake.modules.nixos.virtualization` from its own filename.
They **merge**. And both halves are libvirt config, so importing either name
still gets you working VMs, and the tree still evaluates, and `just diff` still
shows what you expected. Nothing would have looked wrong until someone imported
the category expecting the category.

Caught before it landed, by asking what the aggregate would be named rather
than by anything reporting it — `just modules` does detect it, but only once
the file exists and only if it is run. The file is `libvirt.nix` now, which is
the better name anyway.

**A merge is only visible when the two halves disagree.** When naming a module,
check what its directory is already going to declare — and prefer the specific
name for the file, leaving the general one to the category that hosts import.
