# flake-parts port notes

_Last modified: 2026-09-11_

## Contents

- [Decisions, not defaults](#decisions-not-defaults)
- [Dead ends, with the symptom that identified them](#dead-ends-with-the-symptom-that-identified-them)
- [flake-parts machinery, with the upstream source behind each claim](#flake-parts-machinery-with-the-upstream-source-behind-each-claim)
- [See also](#see-also)

> **Condensed version:**
> [flake-parts-port-notes-for-agents.md](flake-parts-port-notes-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

Salvaged 2026-09-08 from the `flake-parts` branch, which was deleted the
same day. That branch was the sibling of this one — the 2026-08 den →
flake-parts port, done on a darwin laptop against a tree that could only be
evaluated — and it carried two files nothing here reproduced:
`SESSION-HANDOFF.md` and `linux-flake/flake-parts-reference.md`.
[history.md](history.md) and `AGENTS.md` both pointed at it with `git show
origin/flake-parts:…`, which stopped resolving when the branch went.

**This page is an exception to the wiki's "index over restatement" rule**,
on the same terms as [lessons-learned.md](lessons-learned.md) and
[module-style-guide.md](module-style-guide.md): the source it would
otherwise link to no longer exists, so the content lives here or nowhere.
See [styleguide.md](styleguide.md)'s Directory hierarchy section.

**What was left behind.** Most of both files was port mechanics that the
port itself settled — sequencing advice for a migration that has happened,
bug reports against a branch that is gone, "does tenacity build?"
(it does; three hosts have booted since — [hosts.md](hosts.md)). What
survives here is the part that was never reconstructible from the tree:
decisions with reasons, dead ends with symptoms, and machinery claims
backed by upstream source. Everything cut is recoverable while the objects survive:
the branch tip was `cf9aea42`, so `git show
cf9aea42:SESSION-HANDOFF.md` and `git show
cf9aea42:linux-flake/flake-parts-reference.md` still work in a clone that
has fetched it — but a deleted branch's commits are unreferenced and
eventually garbage-collected, which is the reason for this page.

## Decisions, not defaults

From `SESSION-HANDOFF.md` §7, which opened "each of these was an explicit
choice between options I put up, not a default I picked. Re-deciding them
silently would be worse than either answer." Still true, and several are
load-bearing in the tree today:

- **Home Manager NixOS-integrated**, chosen over standalone and over
  keeping both. Live: `nire/system/home-manager/enable-home-manager.nix`,
  and [`../flake/doc/trailhead-home-manager-standalone.md`](<../flake/doc/trailhead-home-manager-standalone.md>)
  is the documented way back.
- **Package parity across hosts.** Offered a role split so the handheld
  would stop getting `vscode`, `gimp`, `libre-office`, `zoom`,
  `github-desktop`, the answer was to keep parity and structure it so the
  split stays available without deciding now. Hosts still install the full
  desktop GUI set on purpose.
- **starship as the prompt for every shell**, powerlevel10k and its
  1,659-line config deleted. See
  [categories/shell-config/](categories/shell-config/README.md).
- **Full per-file dendritic conversion of the package modules**, chosen
  over role-assignable groups and over a structural tidy, boilerplate
  accepted. That is why `nirePackages/` is one file per package.
- **The grep-trail convention** — when a literal name becomes dynamic,
  leave the old string in a comment so the old form still greps to
  somewhere. `AGENTS.md`'s "When a rename makes the old name ungreppable,
  say what it was" is this rule, promoted.
- **Role names `base` / `desktop` / `handheld`**, chosen over
  `workstation`/`handheld`. Superseded since — roles gave way to
  `dirsAsCategory` categories ([architecture.md](architecture.md)) — but
  recorded because the *shape* of the choice recurs.

**On den and flake-aspects, the branch had no opinion and neither should
you infer one.** They were commented out as inputs before that session
started; it never evaluated, tried, or rejected them. The `swap-headers`
and `find-headers` scripts were deleted there because den was already
absent, not as a verdict. The pattern this repo uses is plain flake-parts
plus `import-tree`, which is a data point about feasibility *without* den,
not an argument against it.

**On severity**, from the same file's closing note: "this is a homelab
config, not production. I over-dramatised a four-day window where the flake
did not evaluate and was told, fairly, that the repo has gone six months
between commits." That is where `AGENTS.md`'s Calibrate severity rule comes
from.

## Dead ends, with the symptom that identified them

The ones whose mechanism still applies to this tree. Each is a trap that
produced no error, or an error naming the wrong thing.

- **The two `config`s.** Every file has an outer flake-parts scope and an
  inner NixOS/HM module, both named `config`. A module written as a bare
  attrset has no inner scope, so `config` in it means the flake-parts one;
  adding an argument list to reach the NixOS `config` silently repoints
  every existing `config` in that module, and `config.flake.modules.*`
  stops resolving. Bind what you need from the outer scope in a `let` above
  the declaration — `enable-home-manager.nix` does exactly this and says
  so.
- **`useGlobalPkgs` makes Home Manager reject `nixpkgs.*` outright**, which
  silently dropped an `allowUnfreePredicate` workaround for HM issue #2942.
  `home.profileDirectory` moves to `/etc/profiles/per-user/<user>`, and
  activation becomes a systemd unit whose `PATH` is only
  coreutils/findutils/gnugrep/gnused/systemd with
  `QT_QPA_PLATFORM=offscreen` — anything assuming a login shell will not
  see it. Skill [`home-manager-dotfiles`](../.agents/skills/home-manager-dotfiles/SKILL.md)
  carries these now.
- **starship silently beat powerlevel10k for a whole session.** In the
  generated `.zshrc` the p10k theme was at line 289 and its settings at
  330–1991, while `programs.starship.enableZshIntegration` emitted its init
  at 2025 and ran last. The prompt had been starship all along and 1,660
  lines of p10k config did nothing. **Read the generated dotfile, not the
  module** — that is the only way any of this was visible.
- **`home.file.<n>.text` is `types.lines`**, so it concatenates rather than
  overrides: two modules declaring `.blerc` produced one file with every
  `ble-import` run twice. One owning module per generated file.
- **`ble-import` with an absolute path needs the `.bash` extension.**
  Reading `ble/util/import/search` in the blesh source showed the extension
  fallback applies only to *relative* module names; absolute paths are
  tested with `[[ -e $ret ]]` directly. All five imports would have failed
  silently with no build-time error. Caught by reading source, not by any
  tool.
- **Segment-scoped reference edges reported 119 of 160 modules as
  orphans.** `modules.py tree` attributes a reference to whichever
  declaration's text region it sits in; a name bound in a `let` *above* the
  first declaration belongs to no segment, the edge vanishes, and a whole
  tree detaches. `orphans` uses file-level edges instead, where no edge can
  be lost. The two are deliberately not shared — don't "simplify" them into
  one edge model.
- **Verifying the opt-in mechanism before betting a refactor on it.** A
  throwaway `mkFlake` with two separate modules each setting
  `flake.modules.nixos.workstation.imports` produced a config carrying both
  definitions. That experiment is why the pattern was adopted at all rather
  than assumed to work.
- **The opt-in pattern's one real cost:** omit the opt-in line and *nothing
  happens*. The module is valid Nix, evaluates cleanly, and installs
  nothing — no error is possible, because from the evaluator's point of
  view nothing is wrong. This is why an orphan check runs as a flake check.

## flake-parts machinery, with the upstream source behind each claim

From `linux-flake/flake-parts-reference.md`, which was read out of the
pinned `inputs.flake-parts` rather than the website. **Re-verified
2026-09-08** against the currently pinned `flake-parts`
(`427bf4bd9435fdf21321c8cc628c24efc14c0f7a`); every path and line number
below was checked, not carried over. One correction from the original: the
`_file` string now passes both components through
`lib.strings.escapeNixIdentifier`.

[`../flake/doc/flake-parts-rationale.md`](<../flake/doc/flake-parts-rationale.md>)
covers *which* machinery this repo uses and which it doesn't, by grep. This
section is the complementary half — how the pieces behave, from their
source.

### `flake.modules` — the option everything here is built on

Declared in `extras/modules.nix`, imported at `flake/flake.nix`:

```nix
type  = types.lazyAttrsOf (types.lazyAttrsOf types.deferredModule);
apply = mapAttrs (k: mapAttrs (addInfo k));
```

**The outer attribute name becomes `_class`, unvalidated.** `addInfo`
wraps every module except those under `generic`:

```nix
{ ... }:
{
  _class = class;
  _file  = "${toString moduleLocation}#modules.${escapeNixIdentifier class}.${escapeNixIdentifier moduleName}";
  imports = [ module ];
}
```

The class string is whatever you typed, and flake-parts checks nothing. So
`flake.modules.jovian.wm-jovian` declares happily and fails only later, at
the import site:

```
error: The module `…/flake.nix#modules.jovian.wm-jovian` (class: "jovian")
cannot be imported into a module evaluation that expects class "nixos".
```

That `…#modules.<class>.<name>` in the error is the generated `_file`, so
the error names its own declaration site. Meaningful classes: `nixos`,
`homeManager`, `flake`, `generic`. `homeManager` and `darwin` work only
because those projects set the matching `_class` on their own module
evaluations; `generic` is special-cased to set no class at all, so it loads
anywhere. The wrapper returns a *function* rather than an attrset
deliberately, so it is still accepted as a full module under
`shorthandOnlyDefinesConfig` — the source cites flake-parts issue #326.

**`deferredModule` merges, which is why membership lives with the module.**
Several files may define the same attribute and the module system merges
all of them into one. This is the mechanism behind every category in this
repo, and behind the collision trap in `AGENTS.md` — two modules sharing a
name merge rather than conflict, so a copy-paste that forgets to rename
gives you a module that silently also carries someone else's config.

**Prefer `config.flake.modules.…` over `self.modules.…`.** Both resolve to
the same data, but `self.modules` goes out through the flake's `outputs`
and back in — a longer dependency path and a common source of confusing
recursion.

### `perSystem`

A function from system to flake-like attributes with the `<system>` level
omitted; arguments `pkgs`, `system`, `self'`, `inputs'`, `config`,
`options`, `lib`.

- `pkgs` defaults to `inputs.nixpkgs.legacyPackages.${system}`, **with no
  config applied** — which is exactly why host `pkgs` is not taken from
  here.
- `inputs'.foo = config.perInput system inputs.foo`, so
  `inputs'.foo.packages.bar` rather than
  `inputs.foo.packages.${system}.bar` (`modules/perSystem.nix:82-119`).
- Inside `perSystem`, `self`, `inputs`, `getSystem`, `withSystem` and
  `moduleWithSystem` are bound to *throwing* aliases
  (`modules/perSystem.nix:123-127`) to stop you reaching out of the
  per-system scope by accident.

`checks` is `types.lazyAttrsOf types.package`, so each entry must be a
derivation — which is what lets `modules/checks.nix` turn `nix flake check`
into an evaluation test of every host by forcing `system.build.toplevel`.
Filtering by `nixpkgs.hostPlatform.system` is what makes a check run on
darwin skip the Linux hosts rather than try to build them.

### `withSystem`

Three lines, `modules/withSystem.nix`:

```nix
withSystem = system: f: f (getSystem system).allModuleArgs;
```

where `allModuleArgs = config._module.args // specialArgs // { inherit
config options; }`. So it applies your function to that system's
`perSystem` module arguments, and `config` inside the callback is the
**perSystem** config, not the top-level one. `nireHost/hosts.nix` uses it
for exactly one thing: getting `self'`/`inputs'` into `specialArgs`.
`specialArgs` rather than `_module.args` is what makes them usable inside
`imports`, which is evaluated before `config`.

**Deliberately not done: passing `nixpkgs.pkgs = pkgs` from perSystem.**
Sharing that bare `legacyPackages` would drop `allowUnfree` and break the
unfree packages these hosts install. Letting `nixosSystem` build its own
`pkgs` from the host's own `nixpkgs.config` is the right trade, at the cost
of a second nixpkgs instantiation. `hosts.nix` says so at its head.

**`withSystem` on a system not in `systems` fails** — keep the two in sync.

### `import-tree`

Not flake-parts, but inseparable from how this config reads.
`(inputs.import-tree ./modules)` imports **every** `.nix` file under
`modules/` recursively as a flake-parts module, so file paths carry no
meaning to Nix and files can be moved freely. Non-`.nix` files are ignored,
which is why a module's config files can sit beside it. Paths containing
`/_` are excluded by default — which is what makes `_lib/` work.

The failure mode this creates: a file under `modules/` that is a plain
NixOS module gets handed to flake-parts, which tries to resolve its
`modulesPath` argument through flake-parts' own `_module.args`, and
evaluation dies with an error that blames the wrong thing entirely —

```
… while evaluating the module argument `modulesPath' in ".../hardware-configuration.nix":
… noting that argument `modulesPath` is not externally provided, so querying `_module.args` instead
error: infinite recursion encountered
```

— pointing at `modulesPath`, `_module.args`, and a `config` reference in
`imports`, none of which is the cause. Always wrap:
`{ ... }: { flake.modules.nixos.<name> = <the original module>; }`. Skill
[`new-flake-module`](../.agents/skills/new-flake-module/SKILL.md) carries
this.

### `flake.nixosConfigurations`

`types.lazyAttrsOf types.raw` (`modules/nixosConfigurations.nix`), and its
own docstring makes the split this repo follows explicit: it "is for
specific machines. If you want to expose reusable configurations, add them
to `nixosModules` in the form of modules (no `lib.nixosSystem`)." Here that
is `flake.modules.nixos.*` for the reusable half and
`flake.nixosConfigurations.*` for the instantiated machines.

## See also

- [flake-parts.md](flake-parts.md) — why this repo runs flake-parts at all,
  and the wiki's index into
  [`../flake/doc/flake-parts-rationale.md`](<../flake/doc/flake-parts-rationale.md>).
- [architecture.md](architecture.md) — `dirsAsCategory`, the mechanism
  built on `flake.modules.<class>.<name>`.
- [lessons-learned.md](lessons-learned.md) — §§1–18 are this same port,
  written as it happened.
- [history.md](history.md) — where this page is indexed from, and the rest
  of the repo's own history.
