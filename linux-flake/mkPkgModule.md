# `mkPkgModule`, and why nothing calls it yet

> **Written by Claude Code.** A working note, not documentation.

`modules/nirePackages/_lib/mkPkgModule.nix` is a generator for the
single-package `home.packages` wrapper shape that roughly 70 files under
`nirePackages/` already share by hand:

```nix
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            home.packages = with pkgs; [ which ];
        };
}
```

That shape, and the ones that additionally guard `lib.mkIf (!pkgs.stdenv.isDarwin)`
for Linux-only packages (`vlc.nix`, `gimp.nix`, all of `linux-utils/`, ...), were
identified by counting: 72 of 195 `.nix` files under `modules/` are essentially
this and nothing else. `mkPkgModule.nix` turns each into roughly four lines. See
its own header comment and the worked example at the bottom of that file for the
exact before/after.

**Nothing in the tree calls it.** This is a trailhead, not a conversion --
written to answer "is this worth doing" concretely, without committing to 72
file changes to find out. Same spirit as `dirsAsCategory.md`'s trailhead for
per-module opt-in: the mechanism is described and ready, the decision to use it
is not made here.

## Why it's safe to sit there unused

`import-tree` (the thing that recursively imports every `.nix` file under
`modules/` as a flake-parts module) ignores any path containing `/_` by
default. `mkPkgModule.nix` is a plain function, not a flake-parts module --
calling it the normal way `import-tree` calls files would fail, since it takes
`{ moduleName, packages, ... }`, not the usual `{ config, lib, pkgs, ... }`.
Putting it under `_lib/` keeps it out of that sweep entirely, the same way
`_templates/dirsAsCategory.nix` already relies on this to be a harmless
copy-source rather than a real, empty category.

## What converting would cost

- **~70 one-line-body swaps.** Mechanical, but 70 files is 70 files to review,
  and each one currently carries its own inline comments (some real, most the
  dead `# # description = "..."` line) that a mechanical conversion has to
  decide what to do with.
- **A layer of indirection between the file and what it does.** Right now
  every one of these files is fully readable with nothing else open. After
  conversion, "what does `which.nix` actually do" means also knowing what
  `mkPkgModule.nix` does with its arguments. That's a real cost in a repo whose
  own style guide favours explicit, self-contained modules over cleverness.
- **Relative-import path depth varies per file.** `shell-apps/file-tools/which.nix`
  and `gui-other/media-players/vlc.nix` are different distances from `_lib/`, so
  the `import ../../_lib/mkPkgModule.nix` prefix isn't uniform across call
  sites -- worth getting right file-by-file rather than templating the whole
  edit. The alternative is routing through `inputs.self` for a depth-independent
  absolute path (`import (inputs.self + "/linux-flake/modules/nirePackages/_lib/mkPkgModule.nix")`),
  which trades that friction for putting `inputs` back in the outer signature
  of every converted file.

## If it's ever wanted

1. Convert one category first (`nix-utils/` is the most uniform -- every file
   in it is already exactly this shape) and diff its `toplevel` drvPath before
   and after. Anything other than "identical" means the generator's wrong, not
   the category.
2. Decide the `# # description` question before converting anything that has
   it: carry the text into `mkPkgModule`'s `packages` call as a real (unused
   for now) argument, or drop it. Deciding per-file during a 70-file mechanical
   pass is how it'd end up inconsistent.
3. Widen `packages` to accept a raw `pkgs: [...]` function instead of a string
   list, for the handful of files that need more than `pkgs.${attr}` (multiple
   packages, or a package needing an override) -- don't discover the need for
   this mid-conversion.
