# Port plan: `flake-parts` → `flake-parts-consolidation`

Written 2026-08-07 on `flake-parts-consolidation`. Companion reading, both on
the sibling branch and readable without checking anything out:

```sh
git show flake-parts:SESSION-HANDOFF.md    # what isn't recoverable from the tree
git show flake-parts:SESSION-CHANGES.md    # the 37 commits, and how to port them
```

rename this file to <timestamp>-PORT-PLAN-(COMPLETED).md when finished

---

## The decision, and why it was already made

Bob's kickoff prompt (`claude cave/port-prompt.md`) framed the gate as *keep
vic/den and port ideas onto it, or abandon den and adopt real flake-parts*, and
described this branch as den-based. **That description is wrong**, and the
correction changes the answer:

| | |
|---|---|
| `.nix` files under `linux-flake/modules/` | 178 |
| reference `den` at all | **3** |
| reference `flake-aspects` | **0** — it is an unused input |
| wrapped in `perSystem = …: { flake.modules.<class>.<name> = …; }` | **151** |

The three den files are `entrypoint.nix`, `nireHost/aspect-durandal.nix` and
`nireHost/hosts.nix`. Two of them carry, in the tree already:

```nix
# TODO: this is wrong and will need to be modified for flake-parts
```

And `08fcc74` ("fixed most of the den paths") is a commit converting

```nix
den.aspects.moduleStore._.${moduleName} = den.lib.perUser { homeManager = …; }
```

into

```nix
perSystem = {lib, pkgs, ...}: { flake.modules.homeManager.${moduleName} = …; }
```

So this branch is not a den architecture weighing flake-parts as a future. It is
a **half-finished migration off den that stalled**, 151 of 178 files done, with
den surviving only in the host-wiring layer.

**Decision: abandon den, finish the migration.** This is not a new direction, it
is the direction the tree has been travelling since June.

Note for the record, because the handoff is emphatic about it: den was never
evaluated or rejected on the `flake-parts` branch either — it was gone before
that session began, and deleting the den migration scripts in `4aaeefc` was not
a verdict. Nothing in either branch is evidence *against* den. The argument here
is only that this branch has already paid most of the cost of leaving.

---

## The thing the manual migration got wrong

**`perSystem` stays.** It is core flake-parts, it is not a den concept, and this
port uses it — Phase 3's `checks.nix` is built on it, and a formatter or
devShells would live there too. Nothing below is an argument against `perSystem`.

The mistake is narrower: those 151 conversions put **`flake.modules` inside**
`perSystem`, and that specific pairing cannot work. It is why **no output on
this branch evaluates today**:

```
error: The option `perSystem' does not exist. Definition values:
  - In `…/modules/nireUser/elly/user-settings/elly-user.nix': <function, args: {lib, pkgs}>
  Did you mean `nireUser', `nire' or `nireHost'?
```

That first error is only because `linux-flake/flake.nix` currently has
flake-parts **commented out** in favour of a raw `nixpkgs.lib.evalModules`, so
nothing declares `perSystem` at all. Turning flake-parts back on does not fix
it — it replaces that error with `The option 'flake' does not exist`.

The reason is not arbitrary. `perSystem` is evaluated **once per system**, and
its outputs are transposed into `flake.<output>.<system>.*` — that is what
`modules/transposition.nix` does, and it is why `perSystem.packages.foo` becomes
`flake.packages.x86_64-linux.foo`. It is the right home for anything with a
genuine `<system>` axis.

`flake.modules.<class>.<name>` has no such axis. It is one system-independent
definition, declared at the top level by `flakeModules.modules` as
`lazyAttrsOf (lazyAttrsOf deferredModule)` (`flake-parts/extras/modules.nix:33`).
Defining it inside a per-system loop is a category error, which is why
flake-parts declares no such option there and gives `perSystem` no
`freeformType` to sneak it through — the only `freeformType` in flake-parts is
on the top-level `flake` option (`modules/flake.nix:14`).

So the 151-file transform does not *remove* `perSystem`. It **moves
`flake.modules` out of it**, to the top level where that option is declared.
That is the bulk of this port.

---

## Phase 1 — defects, as small commits

Eight, all verified present in the tree rather than taken from the handoff on
trust. Four are the ones `SESSION-CHANGES.md` part 1 predicted; four are specific
to this branch.

Note on priority: **nothing imports `jovian.nix`.** `aspect-durandal.nix`'s
`moduleList` selects `desktop-env._.kde`, not jovian, and there is no tenacity
host here. So #1 and #2 are real bugs that cannot currently break anything —
they matter when tenacity returns. #3 and #8 are the ones silently affecting the
tree today.

| # | fix | file |
|---|---|---|
| 1 | drop `adjustor` — removed from nixpkgs, folded into `handheld-daemon`; the `services.handheld-daemon.adjustor` option already pulls it in | `nire/desktop-env/jovian/jovian.nix:49,63` |
| 2 | `inputs.jovian.decky-loader` → `config.jovian.decky-loader`; the Jovian flake exposes no such output, and the file already sets that module option | `nire/desktop-env/jovian/jovian.nix:11` |
| 3 | `flake.module.homeManager` → `flake.modules` (singular typo — declares nothing, so micro's config has never applied) | `nirePackages/editors/micro/micro.nix:7` |
| 4 | `initExtraFirst` / `initExtraBeforeCompInit` / `initExtra` → one `initContent` with `mkBefore` / `mkOrder 550` / unordered inside `mkMerge` | `nire/shell-config/zsh/zsh.nix:171,198,207` |
| 5 | drop hand-written `eval "$(starship init bash)"`, which duplicates `programs.starship.enableBashIntegration` | `nire/shell-config/bash/bash.nix:51` |
| 6 | starship for all shells; delete `p10k.zsh`, `zsh-powerlevel10k/` and the p10k lines in `zsh.nix` | `nire/shell-config/zsh/` |
| 7 | `flake.modules.elly` is read but nothing declares it — resolved by Phase 2e, listed here so it isn't lost | `nireHost/aspect-durandal.nix:34` |
| 8 | `collectModules` still filters out `"dirsAsProvides.nix"`, the filename from before `0c0b5f0` renamed providers to categories — so every category containing a *nested* category file collects a phantom module named `dirsAsCategory` | all 24 `dirsAsCategory.nix` |

For #4, move **only** the option and delimiter lines. Leaving the `''` bodies
untouched keeps Nix's indentation stripping from changing the emitted text.

For #8, the four affected categories are `nire/hardware`,
`nirePackages/development`, `nirePackages/gui-other` and
`nirePackages/shell-apps` — each has subdirectories carrying their own
`dirsAsCategory.nix`. `nire/hardware` currently collects
`[ "amdcpu" "amdgpu" "dirsAsCategory" ]`. The Phase 2d repair happens to mask
this (a name nothing declares gets filtered), so fix the filter explicitly
rather than relying on that.

For #6, this repeats a decision already made on the sibling branch: p10k's theme
was never loaded while 1,659 lines of its config were injected, and starship's
init ran last and won regardless.

**These cannot be verified until Phase 2 lands**, because nothing evaluates.
They are correct by inspection only. Re-check all seven once the flake evaluates.
The handoff (§5) argues the reverse order — make it evaluate first, because four
bugs were found hiding behind one another there — and that argument is sound;
this ordering is a deliberate choice to bank the small independent fixes first.

---

## Phase 2 — make it evaluate

### 2a — `flake.nix`

Enable flake-parts properly:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
        inputs.flake-parts.flakeModules.modules
        (inputs.import-tree ./modules)
    ];
    systems = [ "x86_64-linux" "aarch64-darwin" ];
};
```

`flakeModules.modules` is what declares `flake.modules.<class>.<name>` as a
`deferredModule`; without it the whole idiom has no option to write into.

Also in this commit: drop the `den` and `flake-aspects` inputs, drop the unused
`darwin` input, drop the `pipe-operators` `nixConfig` (nothing uses it and it
costs a trust prompt on every fresh checkout), and fill in `description`.

### 2b — delete `modules/entrypoint.nix`

It is entirely den: `den.flakeModule`, four `den.namespace` calls, `den.default`,
`den.ctx.user.includes`, and the `__findFile` angle-bracket shim.

### 2c — unwrap the 151 `perSystem` wrappers

The transform, per file:

```nix
# before
{
    perSystem = {pkgs, lib, ...}:
    let moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { BODY };
    };
}

# after
{ lib, ... }:
let moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    flake.modules.homeManager.${moduleName} = { pkgs, ... }: { BODY };
}
```

Only 13 distinct argument shapes exist, all subsets of
`{ pkgs, lib, config, inputs }`:

| arg | files | where it goes |
|---|---|---|
| `lib` | 151 | stays outer — top-level flake-parts arg |
| `pkgs` | 114 | moves **inward**, to the deferred module's own arg list |
| `inputs` | 8 | stays outer — top-level flake-parts arg |
| `config` | 4 | **by hand**, see below |

Moving `pkgs` inward is not just mechanical tidying — it is the correct fix.
perSystem's `pkgs` defaults to `inputs.nixpkgs.legacyPackages.<system>`, which
has **no `nixpkgs.config` applied**, so `allowUnfree` would be silently lost.
The deferred module's own `pkgs` comes from the NixOS/HM evaluation, which does
have it.

The 4 `config` files need individual attention: this is the two-`config`
shadowing trap. `config` in the perSystem scope is perSystem's config; `config`
in the module body is the NixOS/HM one. Bind whatever the outer scope needs in a
`let` above the declaration rather than trying to reach both from one arg list.

10 files declare two modules each (`elly-user.nix`, `nixfmt.nix`, `nixd.nix`,
`virtualization.nix`, `font.nix`, `zsh.nix`, `fish.nix`, `blesh.nix`, `bash.nix`,
`basic-nix-settings.nix`) — also by hand.

Per handoff §6, prepend-a-header / append-`;}` whole-file wrapping is far safer
than splicing, and the shapes that broke naive rewriting there were: bare
attrsets with no `{ ... }:` header, `{` on the same line as the declaration,
two-module files, and files whose formals had to gain an argument.

Verify with `toplevel.drvPath` afterwards, but expect it to differ — import
reordering permutes list-valued options like `environment.systemPackages`, which
changes the hash without changing the package set. Compare sets, not hashes.

### 2d — repair the 24 `dirsAsCategory.nix`

**Decision: keep directory-derived categories.** They are this branch's own
mechanism (`0c0b5f0`), the category names are already the vocabulary
`aspect-durandal.nix` selects from, and they can be made to work. The per-module
opt-in pattern from the sibling branch is *not* being adopted now — see
`linux-flake/dirsAsCategory.md` for the trailhead if that changes later.

Each `dirsAsCategory.nix` derives a category name from its own directory and
emits:

```nix
flake.modules.nixos.${categoryName}.imports        = allModules;
flake.modules.homeManager.${categoryName}.imports  = allModules;
flake.modules.darwin.${categoryName}.imports       = allModules;
```

where `allModules` is a list of **name strings**. Two problems, both fixable
without abandoning the mechanism:

1. Bare strings in `imports` do not resolve outside den's name lookup. Verified:
   `error: string 'bluetooth' doesn't represent an absolute path`.
2. A directory cannot know **which classes** a module declares. `micro.nix`
   declares only `homeManager`, so `config.flake.modules.nixos.micro` is a
   missing attribute. Emitting all three classes for every name found is wrong.

The repair handles both — resolve names to real references, and filter each
class to the names that class actually declares:

```nix
{ config, lib, ... }:                       # `config` is new; `lib` was already here
let
    # ... categoryDir / categoryName / allModules unchanged ...

    forClass = class:
        map (n: config.flake.modules.${class}.${n})
            (lib.filter (n: config.flake.modules.${class} ? ${n}) allModules);
in
{
    flake.modules.nixos.${categoryName}.imports       = forClass "nixos";
    flake.modules.homeManager.${categoryName}.imports = forClass "homeManager";
    flake.modules.darwin.${categoryName}.imports      = forClass "darwin";
}
```

**This was verified before being written down**, not reasoned about — the
self-reference (reading `config.flake.modules.<class>` while *defining* an
attribute in it) is the part that could plausibly recurse. A model using
flake-parts' exact option type and `apply` from `extras/modules.nix:33,72`
resolves cleanly: a category imports only the modules that declare its class,
`micro` lands in `homeManager` and not `nixos`, and the imported modules' config
actually applies. Redo that check if the mechanism changes.

`dirsAsCategory.nix` is one of the 27 files that never used `perSystem`, so its
outer shape is already correct; it only gains `config` in its argument list.
There is no inner module scope in it, so no shadowing risk.

Two traps to respect when editing it:

- **Always define all three classes, even when the filtered list is empty.**
  Making the *attribute itself* conditional (`lib.optionalAttrs (forClass … != [])`)
  looks tidier and will recurse: computing the attribute names of
  `flake.modules.nixos` would require reading `flake.modules.nixos`. An empty
  aggregate is harmless; a conditional one is not.
- **Fix the stale filename filter in the same commit** — see Phase 1 #8.

Cleanups this enables: `nirePackages/_templates/` contains *only* a
`dirsAsCategory.nix` and no modules, so it can go. And nested categories overlap
their parents by design (`nire/hardware` and `nire/hardware/amd` both collect
`amdcpu`/`amdgpu`) — that is fine and was presumably deliberate under den, but
worth knowing before it looks like a bug.

On `darwin`: only **one** real module declares it — `nireUser/elly/user-settings/`
`elly-user.nix`, which sets `fonts.packages`. The other 24 `flake.modules.darwin`
hits in the tree are `dirsAsCategory.nix` emitting the class for every category.
With the repair those become empty aggregates. Since there are no
`darwinConfigurations` here, decide whether darwin is a real target on this
branch or whether that one module and the `darwin` line in `dirsAsCategory`
should go.

### 2e — rewrite the host wiring

Replace `nireHost/aspect-durandal.nix` and `nireHost/hosts.nix`:

```nix
{ config, inputs, withSystem, ... }:
let
    # withSystem enters flake-parts' per-system scope, which is what makes the
    # system-preselected self' / inputs' available to host modules. pkgs is
    # deliberately *not* taken from perSystem — see 2c.
    mkHost = system: hostModule: withSystem system ({ self', inputs', ... }:
        inputs.nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs self' inputs'; };
            modules     = [ hostModule ];
        });
in
{
    flake.nixosConfigurations.nire-durandal =
        mkHost "x86_64-linux" config.flake.modules.nixos.durandalConfiguration;
}
```

`withSystem` requires the system to be listed in `systems` (2a).

---

## Phase 3 — checks and tooling

Port from the sibling branch, adjusting paths:

```sh
git checkout flake-parts -- linux-flake/scripts/
git checkout flake-parts -- .justfile
```

- **`modules/checks.nix`** — forces every host's `system.build.toplevel`. That
  part is layout-independent and is the high-value half; port it first.
- **The orphan check needs rethinking for categories**, not just repointing. On
  the sibling branch "orphan" means *no module opted it into an aggregate*,
  which is a reachability question over explicit edges. Here membership is
  implicit — a module belongs to its directory's category automatically, so the
  equivalent failure is different: a module in a directory whose **category** no
  host selects, or a category emitted for a class nothing consumes. Worth
  writing against this branch's mechanism rather than porting `modules.py`'s
  edge model wholesale. Its entry-point heuristic also assumes the file
  declaring host configs declares no modules of its own — confirm that holds for
  whatever replaces `nireHost/hosts.nix`.
- **`scripts/add-pkg.sh`** hardcodes `modules/pkgs/{cli,gui,linux-utils}` and the
  `pkgs-*` aggregate names, and writes the opt-in line. Retarget at
  `nirePackages` — and note that under categories it gets *simpler*, since
  creating the file in the right directory is the whole of the membership step.
- **`scripts/host-fingerprint.nix`** and **`scripts/dotfile.sh`** read
  `cfg.nire.primaryUser`; either port that option too or change those lines.
- **`.justfile`** currently holds nothing but comments; recipe paths assume
  `linux-flake/scripts/`.
- `modules.py` deliberately uses **two different edge models** — `tree` uses
  segment-scoped edges, `orphans` uses file-level ones, because segment scoping
  loses `let`-bound references. Do not "simplify" them into one.

`checks` is filtered by system, so on this darwin machine only the orphan check
and the formatter will ever run. The host checks have never executed anywhere,
on either branch.

---

## Phase 4 — `CLAUDE.md`

Written as part of this plan. It describes *this* branch's layout
(`nire`/`nireHost`/`nirePackages`/`nireUser`), not the sibling's
(`nire`/`hosts`/`pkgs`/`users`). Revisit once Phase 2 lands, since the "does not
evaluate" section should then be deleted rather than left to rot.

---

## Deferred, deliberately

- **Tenacity.** Not being re-added during this port. This branch has no tenacity
  files at all — the den restructure dropped the host rather than migrating it.
  Its enrollment in `.sops.yaml` and `secrets.yaml` survives, so the key is still
  valid. When it does come back, regenerate `hardware-configuration.nix` on the
  machine rather than recovering the pre-divergence one from `86d9f6d`, and wrap
  it as a flake-parts module **in the same commit** — see CLAUDE.md.
- **Home Manager: standalone vs NixOS-integrated.** `aspect-durandal.nix` still
  declares `flake.homeConfigurations.elly-nire-durandal`, and `59c481e` ("seeing
  if disabling standalone homes helps") suggests this was mid-thought. The
  sibling branch chose NixOS-integrated; that choice has consequences
  (`useGlobalPkgs` rejects `nixpkgs.*`, which costs the `allowUnfreePredicate`
  workaround at `nire/nix/nix-settings/basic-nix-settings.nix:10`). Decide before
  Phase 2e settles the host wiring, since both touch the same files.
- **The `darwin` input and `macos/`.** This branch has no `macos/` directory —
  the old one is parked at `ignore/macos-old/`. Whether the darwin flake comes
  back as a separate flake is an open question from Bob's prompt; not acting on
  it unasked.
- **Two modules declare the same session config.**
  `nire/shell-config/shell-env/shell-env.nix` and
  `nireUser/elly/elly-session/elly-session.nix` hold byte-identical
  `home.sessionVariables` (12 entries) and `home.sessionPath` (8 entries);
  `shell-env.nix` additionally has `home.shellAliases`. `git log --follow` traces
  both to `3278862`, so this is a split during the den restructure rather than
  one superseding the other, and both land in categories durandal selects.

  Verified against the locked home-manager (`2de7205`): `sessionVariables` is
  `lazyAttrsOf (oneOf …)` and merges silently because the values are equal, but
  `sessionPath` is `listOf str`, so definitions **concatenate — every path entry
  is currently duplicated**. Confirmed by evaluating both types with two
  identical definitions.

  The fix is to delete both options from `elly-session.nix` and let
  `shell-env.nix` own them: it is the more complete of the two and sits with the
  rest of the shell config, whereas `nireUser/elly` is about identity. Held until
  the flake evaluates, since it is the only one of the shell cleanups that
  changes real output and cannot be shown correct before then. This is the
  sibling branch's `.blerc` lesson in a different option — one owning module per
  generated thing.
- **`misc/` is untracked** — it exists on disk, is not in `.gitignore`, and was
  simply never added.

---

## Verification, throughout

Nothing on either branch has ever been built or switched. The dev machine is
aarch64-darwin; the host is x86_64-linux. Every claim of "verified" in this port
means *evaluates and produces the expected derivation*, never *runs*. Say so
plainly rather than implying otherwise.
