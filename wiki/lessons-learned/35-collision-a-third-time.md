# 35. The same collision, a third time — caught immediately because the tool was actually run

_Last modified: 2026-09-29_

§35 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §35's full account.

`containers.nix`, moved into its own category (`nire/containers/`) on
2026-08-22 for the same reason `virtualization` split off `system` a day
earlier, walked straight into §34's exact trap: the new category's
`dirsAsCategory.nix` derives `flake.modules.nixos.containers` from the
directory name, and the file, freshly moved, was still named `containers.nix`
— declaring the identical attribute from its own filename. Same failure
mode as `boot`/`boot-durandal` and `virtualization.nix`/`virtualization`
before it: a category and a module racing for one name, set to merge rather
than conflict.

The difference from both those cases: this one never shipped even briefly.
`just modules` was run as a matter of course before committing (not because
anything looked wrong) and reported it flatly —
`COLLISION 'containers': category modules/nire/containers/ and module
modules/nire/containers/containers/containers.nix declare the same
attribute; they merge` — and it was renamed to `podman.nix` (the actual
technology, same reasoning `libvirt.nix` isn't named `virtualization.nix`)
before any commit existed with the collision in it.

**Three instances of the identical trap in one repo's history is not bad
luck, it's a predictable cost of the category-name-from-directory
mechanism.** The lesson isn't "be more careful" — §34 already said that and
it still happened again. It's: **splitting anything into its own category is
now a specific, checkable moment** — the new directory's basename is a
reserved word for every module filed under it, so name-collision is worth
checking for *by construction* (does any file under here share the
category's own name) rather than by hoping `just modules` gets run before
the commit that matters.
