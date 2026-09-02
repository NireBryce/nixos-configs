---
name: nixos-vm-images
description: How to build a NixOS disk image and wire a libvirt-managed guest VM in this repo.
---

# Building NixOS VM images and wiring libvirt guests in this repo

## Applies to

Building a NixOS disk image or wiring a libvirt guest. The reusable
generator is
`flake/modules/nire/homelab/virtualization/VMs/_lib/libvirt-vm.nix` —
currently uncalled (its only consumer, `nire-llm-sandbox`, was removed
2026-08-28; see `wiki/history.md` and that file's last version in git
history for the full worked example). Use before adding another VM guest,
building any `config.system.build.image`, or debugging a per-host libvirt
module that reached the wrong host.

## `image.modules.<variant>` and `config.system.build.image` are not the same mechanism

Both exist in nixpkgs, both can build a qcow2 from `make-disk-image.nix`,
and they don't compose:

- **`image/modules/images.nix`** (`image.modules`,
  `system.build.images.<variant>`) builds each variant as an **isolated**
  `extendModules` sub-configuration — its own `fileSystems`, bootloader,
  everything — none of it feeding back into the base config.
- **`virtualisation/disk-image.nix`** is what the variant imports
  internally. Imported **directly** into a real `nixosConfiguration`
  (`modulesPath + "/virtualisation/disk-image.nix"`, setting
  `image.efiSupport` yourself), it makes `fileSystems."/"` and the
  bootloader part of the base config.

Why it matters here: `checks.nix` forces `system.build.toplevel` for every
`nixosConfigurations` entry. A guest built via `image.modules.qemu` has no
root `fileSystems` or `boot.loader.grub.devices` in its *base* config —
they only exist in the isolated variant — so the toplevel eval fails with
"the `fileSystems` option does not specify your root file system". Hit for
real; exact assertion text in `llm-sandbox-configuration.nix`'s header (git
history).

**The rule**: import `disk-image.nix` directly into the base config, so
`config.system.build.image` and `config.image.filePath` are real values on
the same config whose toplevel gets checked.

## `image.filePath` is relative to the image derivation's `$out`, not absolute

It's a filename, not a store path, however much it looks like one once
interpolated. Using it bare produces a path that only resolves if cwd is the
derivation's output dir — which nothing ever is.

This did **not** show up at evaluation: `nix eval` happily returned the
generated script with the bare filename substituted in. The bug appeared
only when the script was built and read back — it was checking
`[ -e "nixos-image-qcow2-....qcow2" ]`. §25/§1 shape: eval success says
nothing about the string being *correct*.

**The fix**: combine them yourself —
`"${theImageDerivation}/${theConfig.image.filePath}"` — and if a value
matters at runtime and builds cheaply, build and read the artifact back
before trusting the string.

## Keeping a generator's consumer host-exclusive without hiding the generator

Two different exclusion mechanisms, for entirely different reasons — don't
confuse them:

- **The reusable generator goes under `_lib/`** (`VMs/_lib/libvirt-vm.nix`):
  it's a plain curried function (`{ name, image, ... }: { pkgs, lib, ... }:
  ...`), which `import-tree` cannot auto-import at all (closed lambda, no
  `...`) — and `import-tree` ignores any path containing `/_`, same as
  `nirePackages/_lib/` and `nire/impermanence/_disko/`.
  `dirsAsCategory` has no `_` special case but finds nothing to collect
  there anyway, since nothing under `_lib/` ever declared a module.
- **The host-exclusive caller sat bare in the category directory itself**,
  in no subdirectory — the *other* half of the rule ("a `.nix` file sitting
  directly in a category directory is collected by nothing"), per
  `flake/doc/dirsAsCategory.md`. That kept it out of the `virtualization`
  aggregate (durandal imported the category too, at the time); only an
  explicit line in the host's own imports reached it. The next
  host-exclusive VM caller wants the same placement.

Both look like "not automatically collected", but a `_`-prefixed path is
invisible to *both* mechanisms — nothing, on any host, would ever import it.
Verify which problem you're solving before reaching for either.

## Verify

- `just modules` — name collisions, free.
- `nix eval --raw '.#nixosConfigurations.<name>.config.system.build.toplevel.drvPath'`
  for every host touched, *including* ones that shouldn't change — a
  byte-identical drvPath is real proof the change stayed scoped.
- `nix build --no-link --print-out-paths` on the derivation whose *content*
  matters (script, domain XML, image), then read the result. Eval proves
  type-check; build-and-read proves the string is correct. This is where
  the `image.filePath` bug was found.
