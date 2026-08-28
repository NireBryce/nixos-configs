---
name: nixos-vm-images
description: How to build a NixOS disk image and wire a libvirt-managed guest VM in this repo.
---

# Building NixOS VM images and wiring libvirt guests in this repo

## Applies to

Building a NixOS disk image (qcow2/raw/etc.) and wiring a libvirt-managed
guest VM in this repo — covers nixpkgs' image-variant system vs. its
underlying disk-image module, the relative-path gotcha in `image.filePath`,
and the category-scoping trick used to keep a generator's *consumer*
host-exclusive without hiding the generator itself. Use before adding
another VM guest (`nireHost/llm-sandbox/`, `nire/virtualization/VMs/` are the
worked example), building any `config.system.build.image`, or debugging why
a per-host libvirt module reached a host it shouldn't have (or didn't reach
the one it should).

Background: `nire-llm-sandbox` (`flake/modules/nireHost/llm-sandbox/`) and
its libvirt wiring (`flake/modules/nire/virtualization/VMs/_lib/libvirt-vm.nix`,
`flake/modules/nire/virtualization/virtualization-cube.nix`) are the worked
example everything below was learned from, 2026-08-22. Read those files'
own headers for the full account; this is the trap-shaped summary.

## `image.modules.<variant>` and `config.system.build.image` are NOT the same mechanism

Both exist in current nixpkgs, both can build a qcow2 from the same
underlying `nixos/lib/make-disk-image.nix`, and it is easy to assume they
compose. They don't.

- **`nixos/modules/image/images.nix`** (`image.modules`, `system.build.images.<variant>`)
  is part of every NixOS configuration's module list already. Each variant
  name (`qemu`, `amazon`, `iso`, …) maps to a module, and that module is
  built as an **isolated** configuration via `extendModules` — its own
  `fileSystems`, its own bootloader, its own everything. None of that feeds
  back into the *base* configuration's own `config`.
- **`nixos/modules/virtualisation/disk-image.nix`** is the module that
  variant actually imports internally (`imports = [ ../virtualisation/disk-image.nix ]; image.efiSupport = false;`
  for the `qemu` variant specifically). Importing it **directly** into a
  real `nixosConfiguration` (via `modulesPath + "/virtualisation/disk-image.nix"`,
  the same mechanism a live-ISO profile uses)
  makes `fileSystems."/"` and the bootloader part of the *base* config too.

**Why the difference matters here specifically**: `checks.nix` forces
`system.build.toplevel` for every `nixosConfigurations` entry (that's the
whole point of the file — "evaluating a cheap attribute proves nothing").
A guest built through `image.modules.qemu` evaluates its *image* fine but
fails its own *toplevel* with "the `fileSystems` option does not specify
your root file system" and no `boot.loader.grub.devices` — because those
only exist inside the isolated variant sub-config, not the base one
`system.build.toplevel` is asking about. This was hit for real, not
theorized: see `llm-sandbox-configuration.nix`'s header for the exact
assertion text.

**The fix, and the rule**: import `disk-image.nix` directly into the base
config (setting `image.efiSupport` yourself) rather than going through
`image.modules`/`system.build.images`. That makes `config.system.build.image`
(singular — the raw derivation) and `config.image.filePath` both real,
directly-readable values on the SAME config whose toplevel gets checked, with
nothing isolated behind `extendModules`.

## `image.filePath` is relative to the image derivation's own `$out`, not absolute

Easy to misread as a ready-to-use in-store path, because it looks like one
once interpolated (`nixos-image-qcow2-26.11.....qcow2`). It isn't — it's
just the filename, and using it bare produces a path that only resolves if
the process happens to be running with the derivation's own output
directory as its cwd, which nothing ever does.

**This did not show up at evaluation.** `nix eval` on the consuming
attribute (a systemd unit's `ExecStart`, in this case) happily returned a
store path to the generated *script*, string-substituted and all. The bug
only appeared when that script was actually **built** and read back — the
generated shell script was checking `[ -e "nixos-image-qcow2-....qcow2" ]`,
a bare filename, instead of an absolute path. Same shape as this repo's
`lessons-learned.md` §25 ("running it is a rung of its own, and finds a
different class [of bug]") and §1 (a tool reporting success while being
wrong) — `nix eval` succeeding said nothing about the string it produced
being *correct*, only that it type-checked.

**The fix**: combine the derivation and the relative path yourself —
`"${theImageDerivation}/${theConfig.image.filePath}"` — rather than using
either alone. If a value here matters at runtime and you can build it
cheaply, build it and read the artifact back before trusting the string.

## Keeping a generator's *consumer* host-exclusive without hiding the generator

`dirsAsCategory` collects every `.nix` file from every *sub*directory of a
category unconditionally — see `flake/doc/dirsAsCategory.md` and the
`new-flake-module` skill's collision-merge warning. That means a module
placed in a normal subdirectory of e.g. `nire/virtualization/VMs/` is
automatically part of `flake.modules.nixos.virtualization`, reaching every
host that imports the category whole — not just the one host you wrote it
for.

The pattern used here has two separate pieces filed in two separate places,
each for a different reason:

- **The reusable generator** (`VMs/_lib/libvirt-vm.nix`) is a **plain
  curried function**, not a flake-parts module — it can't declare
  `flake.modules.<class>.<name>` because it's parameterized (`{ name, image,
  ... }: { pkgs, lib, ... }: {...}`), and if `import-tree` tried to
  auto-import it the normal way it would call it with flake-parts' own
  module args and fail outright (closed lambda pattern, no `...`). It goes
  under `_lib/` for the same reason `nirePackages/_lib/mkPkgModule.nix` and
  `nire/impermanence/_disko/impermanence-luks-btrfs.nix` do: `import-tree`
  ignores any path containing `/_`. `dirsAsCategory`'s own directory walk
  does NOT skip `_`-prefixed paths (it has no special case for them), but it
  harmlessly finds nothing to collect there anyway, because nothing under
  `_lib/` ever declared `flake.modules.nixos.<name>` in the first place —
  `import-tree` never touched it to make that declaration happen.
- **The host-exclusive caller** (`virtualization-cube.nix`) sits **bare in
  the category directory itself**, not in any subdirectory — the OTHER half
  of `dirsAsCategory`'s rule ("a `.nix` file sitting directly in a category
  directory is collected by nothing"). This is what keeps it out of the
  `virtualization` aggregate: durandal also imports `virtualization`, and
  without this placement it would get the VM too. Only an explicit,
  separate `virtualization-cube` line in `cube-configuration.nix`'s own
  imports reaches it.

**These two exclusion mechanisms look similar (both "not automatically
collected") but are for entirely different reasons** — one because
`import-tree` can't handle a bare function at all, the other because
`dirsAsCategory` specifically only walks subdirectories. Confusing them (e.g.
"just put it under `_lib/` to keep it cube-only") would be wrong: a
`_`-prefixed path is invisible to *both* mechanisms, so nothing would ever
import it at all, from any host. Verify which problem you're actually
solving before reaching for either one.

## Verified this way, cheaply, before trusting any of it

- `just modules` — catches the module-name-collision class of bug (see
  `new-flake-module` skill), immediately and for free.
- `nix eval --raw '.#nixosConfigurations.<name>.config.system.build.toplevel.drvPath'`
  for every host touched, INCLUDING ones that shouldn't have changed — a
  byte-identical drvPath there is real proof a change stayed scoped, not
  just an assumption.
- `nix build --no-link --print-out-paths` on the specific derivation whose
  *content* matters (a generated script, a domain XML, the image itself),
  then `Read` the result. Evaluation proves the Nix expression type-checks;
  building and reading proves the string it produced is actually correct.
  This is where the `image.filePath` bug above was actually found.
