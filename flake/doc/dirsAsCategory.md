# `dirsAsCategory`, and the trailhead out of it

> **Written by Claude Code.** A working note, not documentation: it records how one mechanism here works and what it cost to find out. Accurate as far as it was checked, and more thorough about its own reasoning than a human would bother being.


Two things: how the category mechanism works and why it is shaped the way it is,
and — if you ever want to — how to convert it to per-module opt-in.

**Nothing here is a recommendation to convert.** Categories were chosen
deliberately (`0c0b5f0`), and repaired rather than replaced during the
flake-parts port. This document exists so that decision stays reversible by
someone who wasn't there, not to argue against it.

---

## How it works

Every category directory holds a copy of `dirsAsCategory.nix`. As of
2026-08-27 that copy is a two-line shim — the actual logic lives once, in
`modules/_lib/category-collector.nix`, and every copy is now byte-identical
(confirmed by hashing all of them; before this change three had drifted by a
comment word, and `nirePackages/_templates/dirsAsCategory.nix`, inert because
`import-tree` ignores `/_` paths, carried an extra header paragraph — see
`history` below for why that drift didn't need fixing on its own):

```nix
{ config, lib, ... }:
let
  categoryDir = dirOf __curPos.file;
  findModulesRoot = dir: if baseNameOf dir == "modules" then dir else findModulesRoot (dirOf dir);
in
import (findModulesRoot categoryDir + "/_lib/category-collector.nix") {
  inherit config lib categoryDir;
}
```

`categoryDir = dirOf __curPos.file` has to stay in the shim, not move into the
shared file: `__curPos.file` resolves to wherever that token is written in
source, at parse time, so if the shared file computed it, every category would
resolve to the shared file's own directory instead of the caller's. `findModulesRoot`
walks up to find `modules/` so the shim can reach `_lib/` from any nesting
depth with the same two lines everywhere — **not** via `inputs.self`, which
looks like the obvious depth-independent path and does not work here: unlike
a NixOS module's use of `inputs.self` (evaluated downstream once `self`
already exists), a `dirsAsCategory.nix` shim is itself one of the flake-parts
modules that compose `self`, so referencing `inputs.self` from inside it
forces the very fixed point it contributes to and fails as `infinite
recursion encountered`. Confirmed by trying it before writing the walk-up
version.

The shared file derives the category name from the directory it's handed,
walks the subdirectories collecting `.nix` filenames, and declares one
aggregate per module class:

```nix
categoryName = baseNameOf categoryDir;
# …
flake.modules.nixos.${categoryName}.imports       = forClass "nixos";
flake.modules.homeManager.${categoryName}.imports = forClass "homeManager";
flake.modules.darwin.${categoryName}.imports      = forClass "darwin";
```

`forClass` resolves the collected names to real module references and drops any
name that class does not declare:

```nix
forClass = class:
    map (n: config.flake.modules.${class}.${n})
        (lib.filter (n: config.flake.modules.${class} ? ${n}) allModules);
```

**Membership is therefore implicit: a module belongs to the category of the
directory it is filed in.** Adding a module is a one-file change — create the
file in the right place and it is in. That is the mechanism's whole appeal.

**A nested category (`nire/hardware/amd/`, `homelab`'s seven children,
`nirePackages/development/langs`, ...) is referenced by name instead of
walked from scratch by every ancestor.** If a subdirectory owns its own
`dirsAsCategory.nix`, the collector adds that subdirectory's own name to the
list — `forClass` then resolves it exactly like a plain module name, because
a nested category's aggregate lives in the same `flake.modules.<class>`
namespace a leaf module's does, and the "always define all three classes,
even empty" rule below guarantees it exists for every class regardless of
what that subtree actually collected.

This took two wrong attempts to get right, both caught by evaluating rather
than by reasoning about the diff, in the same session that factored the
logic out:

- **First version: dead code.** The boundary check lived only inside
  `collectModules`, which `modulesOf` invokes already *inside* each of
  `categoryDir`'s immediate subdirectories — so the check never got to
  examine an immediate subdirectory as a delegation candidate, only a third
  level of nesting this repo doesn't have anywhere. The `drvPath` fingerprint
  used to verify the refactor came back byte-identical for this version too,
  for the mundane reason that nothing had actually changed, not because it
  was safe.
- **Second version: live, but silently wrong.** Applying the same check one
  level up (so `hardware` delegates to `amd`'s aggregate and `homelab`
  delegates to `virtualization`'s) made it fire at the real depth, and
  silently dropped `libvirt-vm-llm-sandbox` from `nire-cube`'s
  `systemd.services` entirely. Cause: `virtualization-cube.nix` (the
  `nire-llm-sandbox` VM's cube wiring — both since removed, 2026-08-28; see
  `wiki/history.md`) sat bare in `nire/homelab/virtualization/`'s own root,
  deliberately excluded from the
  `virtualization` category's own aggregate (a `.nix` file bare in a
  category's own root is collected by nothing — see "Things that are
  load-bearing" below) — but it reached `nire-cube` at all only because
  `homelab` used to walk into `virtualization/` independently, as *its*
  subdirectory, where a bare file one level in was never excluded (see
  `wiki/categories/virtualization.md`'s "This exclusion is category-scoped,
  not tree-scoped" section). Delegating straight to `virtualization`'s
  aggregate collapsed that independence and lost exactly that file.
  Confirmed by evaluating `nire-cube`'s `config.systemd.services` before and
  after, not just reasoned about.

The fix that actually shipped delegates AND separately re-collects any bare
`.nix` files sitting directly in the nested category's own root — the files
its own aggregate deliberately excludes, that a plain recursive walk would
otherwise still have swept in. That's `bareModulesOf` in
`category-collector.nix`. Verified against all six configurations
(`nire-durandal`, `nire-cube`, `nire-tenacity`, `nire-lego`,
`nire-llm-sandbox`, `nire-lysithea`): `environment.systemPackages`,
`systemd.services`, and `users.users` all came back exactly identical to the
pre-refactor baseline, `libvirt-vm-llm-sandbox` included. `drvPath` itself
does shift on most hosts — expected, per "Expect `drvPath` to change from
import reordering alone" below, since a nested category is now referenced
once instead of having its modules listed a second time.

### Things that are load-bearing

- **Always define all three classes, even when the filtered list is empty.**
  Making the attribute itself conditional — `lib.optionalAttrs (forClass … != [])` —
  looks tidier and recurses: computing the attribute names of
  `flake.modules.nixos` would require reading `flake.modules.nixos`. Empty
  aggregates are harmless. Conditional ones are not.
- **The class filter is not optional.** A directory cannot know what a module
  declares. `micro.nix` declares only `homeManager`; without the filter,
  `flake.modules.nixos.editors` asks for `config.flake.modules.nixos.micro`,
  which does not exist.
- **Nested categories overlap their parents on purpose.** `nire/hardware` and
  `nire/hardware/amd` both collect `amdcpu` and `amdgpu`, because `collectModules`
  recurses. That gives coarse and fine handles on the same modules. It looks
  like a bug and is not.
- **The name filter must match the current filename.** It excluded
  `dirsAsProvides.nix` for a while after the file was renamed to
  `dirsAsCategory.nix`, so nested categories collected a phantom module called
  `dirsAsCategory`. The class filter masks that symptom, which is exactly why
  the filter itself has to be right.

### Verifying a change to it

The self-reference — reading `config.flake.modules.<class>` from a file that
also *defines* an attribute in it — is the part that can plausibly blow up. It
resolves cleanly today, but that was established by building a model with
flake-parts' exact option type and `apply`
(`flake-parts/extras/modules.nix:33,72`) and evaluating it, not by reasoning.
Do the same rather than assuming, and check three things: a category imports
only modules declaring its class, an imported module's config actually applies,
and no category name is missing.

---

## What the alternative is

The sibling `flake-parts` branch uses per-module opt-in instead. Each module
declares which aggregates it belongs to, next to its own definition:

```nix
{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports =
        [ config.flake.modules.homeManager.ripgrep ];

    flake.modules.homeManager.ripgrep = { pkgs, ... }: {
        home.packages = [ pkgs.ripgrep ];
    };
}
```

`flake.modules.<class>.<name>` is a `deferredModule`, so many files can define
the same aggregate and the module system merges them. A separate `roles.nix`
declares only the hierarchy between aggregates; nothing lists a roster.

### Why you might want it

- **Directory and membership come apart.** A module can live wherever it reads
  best and still belong to whatever aggregate is right. Under categories, moving
  a file changes what installs it — which cuts against the whole reason this
  repo uses `import-tree` (paths carry no meaning).
- **One module, several aggregates, no duplication.** Today the only way a
  module joins two categories is to sit under both, or for one category to
  nest inside the other.
- **Roles get cheap.** `base` / `desktop` / `handheld` with modules opting into
  more than one is awkward to express through directories, and it is exactly
  what a second host needs. This is the strongest reason, and it becomes real
  the moment tenacity comes back.
- **It is explicit.** You can grep a module and see where it goes.

### What it costs

- **~150 one-line additions**, one per module.
- **No file lists a roster any more.** There is no `desktop.nix` to open. The
  sibling branch answers this with `just modules`, a static-analysis script that
  reconstructs membership, plus `--reverse` to invert it. If you convert, port
  that in the same change or the layout gets genuinely hard to read — this was
  raised there *after* adoption and the script is what settled it.
- **A new silent failure mode.** Omit the opt-in line and nothing happens: the
  module is valid, evaluates cleanly, installs nothing, and no evaluation can
  ever produce an error. Categories cannot fail this way, because membership is
  automatic. The sibling branch runs a reachability check as a flake check
  specifically to cover this, and it is not optional there.
- **Name collisions merge instead of erroring.** Module names share one
  namespace per class, so a copy-paste that forgets to rename yields one module
  silently carrying both configs. Their `add-pkg.sh` refuses duplicate names for
  this reason.

---

## How to convert, if you decide to

Order matters; each step's precondition is the previous one.

1. **Get a fingerprint first.** Capture
   `nixosConfigurations.<host>.config.system.build.toplevel.drvPath` and an
   attribute sample (`environment.systemPackages` names, `systemd.services`,
   `users.users`, `environment.etc`) on a tree that evaluates. A fingerprint of
   a broken tree is worthless, and this refactor is meant to preserve behaviour
   exactly.

2. **Decide the aggregate names before touching files.** The natural choice is
   to keep the existing category names — `development`, `editors`, `gui-other`,
   `linux-utils`, `nix-utils`, `shell-apps`, `terminals`, and the `nire/*` ones —
   so the conversion changes only *how* membership is established, not what the
   groups are called. `aspect-durandal.nix`'s `moduleList` is then still the
   host's roster, unchanged. Renaming at the same time makes the diff
   unreviewable.

3. **Generate the opt-in lines from the categories themselves.** The current
   `dirsAsCategory` output *is* the answer key: for each category, the list of
   modules and the classes each declares. Emit one `imports` line per
   module/class pair and insert it above that module's own declaration. Do this
   mechanically — hand-editing 150 files invites exactly the omission that has
   no error.

4. **Keep an intermediate tier if the roles are ever going to differ.** Package
   categories feeding a role, rather than each package joining the role
   directly, is what lets a host take some categories and not others later
   without touching 100+ files.

5. **Delete the `dirsAsCategory.nix` copies last**, once the opt-in lines are in
   and the fingerprint matches. Deleting first means the tree stops working and
   you lose the ability to diff against it. (This count was 24 when first
   written and is 37 as of the 2026-08-27 refactor below — recount rather than
   trusting either number; nothing here derives it mechanically.)

6. **Add the reachability check in the same change.** Not after. Step 3's
   failure mode is silent, and it is the only one that no amount of evaluating
   will surface. `git show flake-parts:linux-flake/scripts/modules.py` is a
   starting point; note it deliberately uses two different edge models —
   segment-scoped for display, file-level for the check — because segment
   scoping loses `let`-bound references and reported 119 of 160 modules as dead.

Expect `drvPath` to change from import reordering alone: permuting
`environment.systemPackages` changes the hash without changing the package set.
Compare sets, not hashes.

---

## History

**2026-08-27 — factored out of 37 duplicated copies.** Before this, every
`dirsAsCategory.nix` (38 of them, `_templates`' inert copy included) carried
the full ~35-line logic inline, copy-pasted. Hashing all of them first found
they weren't quite identical — one comment word
(`"Subcategories are directories at this level"` vs `"... , ie under ./"`)
had drifted across three files, and the inert `_templates` copy carried an
extra explanatory header paragraph plus a reference to the mechanism's
pre-rename filename, `dirBasedProvides.nix`. None of that was a behavior
difference — every copy still produced the same `collectModules`/`forClass`
logic — so none of it needed preserving as `history` anywhere: it was drift
in wording, not a stranded decision or a bug.

The refactor moves the logic into `modules/_lib/category-collector.nix`
(kept out of `import-tree`'s sweep the same way `nirePackages/_lib/` and
`nirePackages/_templates/` already are — any path containing `/_`), leaving
each copy as the two-line shim shown above. Verified by getting `drvPath`
fingerprints for `nire-durandal` and `nire-cube` (the deepest nested-category
user, via `homelab`) before touching anything, converting one file
(`nire/boot/`) first and re-checking before rolling out to the rest, and
confirming both hosts' `drvPath` came back **byte-identical**, not just
attribute-equal, after all 37 were converted. `just modules` stayed clean
throughout.

Reaching the shared file was tried via `inputs.self` first, specifically
because it looked like the obvious depth-independent path; it isn't one, for
the reason in the code comment above, and cost one throwaway single-file
test (`nire/boot/`, still under version control at that point so nothing was
lost) to find out before it would have been baked into all 37.

**The same session also added nested-category delegation, in three passes**
— see "A nested category ... is referenced by name" above for the mechanism
that shipped, and `category-collector.nix`'s own header for the two wrong
versions in full. Worth recording here specifically because of how close it
came to shipping quietly wrong at each intermediate step: the first version
was dead code (never fired at this repo's actual nesting depth), which meant
the very fingerprint checks that verified the rest of this refactor —
byte-identical `drvPath` on `durandal` and `cube` — passed for that version
too, for the mundane reason that nothing had actually changed, not because
delegation was safe. Making it fire at the real depth is what surfaced the
`libvirt-vm-llm-sandbox` drop, and only because that specific case was
checked by evaluating `config.systemd.services` directly rather than
trusting `drvPath` equality to keep holding as the code changed further. The
fix (`bareModulesOf`, carrying a nested category's own bare files along with
the delegated reference) was then verified the same way, plus a full
attribute-set diff (`environment.systemPackages`, `systemd.services`,
`users.users`) against the pre-refactor baseline on every one of the six
configurations, not just the one that had already broken once. A green
fingerprint check proves the version you ran it against; it says nothing
about the next edit, which is why the fix got the same treatment as the bug
that preceded it, not just a spot-check on the one host already known to be
at risk.

## Related reading

- `2026-08-08-PORT-PLAN-(COMPLETED).md` — Phase 2d, where the
  repair-not-replace decision was made.
- `git show flake-parts:SESSION-HANDOFF.md` §6 — the sibling branch's account of
  the opt-in pattern: what it replaced, its four failure modes, and the
  mechanics of converting ~140 files to it.
