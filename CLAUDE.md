# CLAUDE.md

Guidance for Claude Code working in this repository, on the
`flake-parts-consolidation` branch.

## Safety

The README's warning is real: this config enables impermanence and wipes `/root`
on boot. Never suggest installing it wholesale on a machine, and be careful with
anything touching `linux-flake/modules/nire/boot/impermanence/` or the
`fileSystems`/`boot` options in the host hardware modules.

Secrets are sops-nix (`linux-flake/modules/nire/system/secrets/`).
`secrets.yaml` is encrypted and committed; that is deliberate, not a mistake to
be "fixed". Its `.sops.yaml` still enrolls `nire-tenacity` even though that host
has no config here any more — the key is valid, leave it.

## Read this first: the flake does not evaluate

No output on this branch evaluates. Not one host, not `networking.hostName`:

```
error: The option `perSystem' does not exist. Definition values:
  - In `…/modules/nireUser/elly/user-settings/elly-user.nix': <function, args: {lib, pkgs}>
```

The cause is structural, not a typo. `linux-flake/flake.nix` has flake-parts
**commented out** and uses a raw `nixpkgs.lib.evalModules` instead, while 151 of
the 178 module files are written in flake-parts idiom and wrap themselves in
`perSystem`. Nothing declares that option.

**Do not treat this as a bug to patch locally.** It is the visible end of a
half-finished migration off `vic/den`, and `PORT-PLAN.md` is the plan for
finishing it. Anything you verify before that lands is unverified in practice —
evaluation is the only check available here, and it currently returns nothing
useful.

A consequence worth internalising, from the sibling branch's experience: on a
tree that cannot evaluate, bugs **serialize**. Four were found there stacked
behind one another, each invisible until the previous was fixed. Assume the
defect list below is incomplete.

## Repo shape

Three top-level areas. Only `linux-flake/` is a flake.

- **`linux-flake/`** — the live config and where essentially all work happens.
  One host: `nire-durandal` (workstation). `nire-tenacity` (handheld,
  Jovian/SteamOS) exists in the git history and in `.sops.yaml`, but the den
  restructure dropped the host rather than migrating it, so there are no
  tenacity files here at all.
- **`ignore/`** — parked material: the old macOS flake (`ignore/macos-old/`), old
  modules, util scripts. Not wired into anything. Despite the name it is
  **tracked** and not in `.gitignore`.
- **`misc/`** — exists on disk, is not ignored, and was never `git add`ed. Treat
  as scratch.

There is no `macos/` directory on this branch. `claude cave/` holds notes the
user keeps for chasing cryptic errors; `den-reference.md` and `project-vibes.md`
in it are currently empty files.

Everything below is about `linux-flake/`.

## Commands

There is no working `just` yet — the root `.justfile` is nothing but commented
example lines. Porting real recipes is Phase 3 of `PORT-PLAN.md`. Until then,
raw nix:

```sh
cd linux-flake

# The only check that means anything. Currently fails; see above.
nix eval --raw .#nixosConfigurations.nire-durandal.config.system.build.toplevel.drvPath

# Evaluates every output, builds nothing.
nix flake check --all-systems --no-build

# Read a generated dotfile as home-manager actually emits it.
nix eval --raw '.#nixosConfigurations.nire-durandal.config.home-manager.users.elly.home.file.".zshrc".text'
```

In that last command `elly` is literal on purpose: it reads an *evaluated*
config, where the attribute name is already resolved. Only module **source**
should go through an option rather than hardcoding the name.

The `home.file` attribute name is inconsistent and worth checking first with
`--apply builtins.attrNames` — on the sibling branch it has been `".zshrc"`,
`"./.zshrc"` and a full `/home/elly/…` path for different entries, and some
entries have no `.text` at all because they are built from `.source`.

**Development is on darwin; the host is `x86_64-linux`.** Evaluation works
cross-platform, building does not. Nothing in this repo has ever been built or
switched from the dev machine — that would need a remote builder or binfmt
emulation, neither of which is set up. Any claim that something builds must say
so honestly. "Evaluates and produces the expected derivation" is the strongest
true statement available here.

## Architecture: where this is going, and where it actually is

### The intent

`flake.nix` is a manifest and nothing else. `(inputs.import-tree ./modules)`
recursively imports **every** `.nix` file under `linux-flake/modules/`, so paths
carry no meaning beyond naming and files can be moved freely without editing any
import. That is the point, per the README.

**Every `.nix` file under `modules/` is a flake-parts module** — its top level is
`{ flake.modules.<class>.<name> = …; }` or similar, never a bare NixOS or Home
Manager module.

### Where it actually is

| | |
|---|---|
| files under `modules/` | 178 |
| reference `den` | 3 — `entrypoint.nix`, `nireHost/aspect-durandal.nix`, `nireHost/hosts.nix` |
| reference `flake-aspects` | 0 (it is an unused input) |
| wrapped in `perSystem` | 151 |
| `dirsAsCategory.nix` files | 24 |

Two of the three den files already say
`# TODO: this is wrong and will need to be modified for flake-parts` in the tree.
`08fcc74` is the user converting den module bodies into flake-parts ones by hand.
The direction of travel is off den; it just stopped partway.

Module counts by area: `nirePackages` 117, `nire` 47, `nireHost` 8, `nireUser` 5.
Declarations by class: `homeManager` 131, `nixos` 76, `darwin` 25, and one
`flake.modules.elly` at `aspect-durandal.nix:34` that nothing declares. The 25
`darwin` declarations are inert — there are no `darwinConfigurations` here.

## Traps, all verified on this tree

### `perSystem` cannot set `flake.*`

This is the one that matters most, because 151 files depend on it. `perSystem`
is a distinct module type (`flake-parts-lib.mkPerSystemType`) with its own
options. The only `freeformType` anywhere in flake-parts is on the **top-level**
`flake` option (`flake-parts/modules/flake.nix:14`). There is no freeform escape
inside `perSystem`.

So turning flake-parts back on does not fix the current error, it replaces it
with `The option 'flake' does not exist`. The wrappers have to come off.

`perSystem` is **core flake-parts**, incidentally — declared in
`flake-parts/modules/perSystem.nix`, loaded from `all-modules.nix:16` next to
`withSystem.nix`. It is not a den or flake-aspects concept, and a previous
instance got this wrong in a way that would have distorted the whole den
decision.

### Bare strings in `imports` do not resolve

All 24 `dirsAsCategory.nix` files build a list of module *names* and emit
`imports = allModules`. Outside den's name resolution that fails:

```
error: string 'bluetooth' doesn't represent an absolute path
```

Beyond that, a directory cannot know which classes a module declares —
`micro.nix` declares only `homeManager`, so emitting
`flake.modules.nixos.editors.imports = [ … micro … ]` asks for an attribute that
does not exist. Only the module itself knows. That is the structural reason the
opt-in pattern replaces this, not a matter of taste.

### Raw NixOS modules in the import-tree path

Dropping a raw NixOS module into `modules/` — for example fresh
`nixos-generate-config` output — makes flake-parts try to resolve that module's
`modulesPath` argument through its own `_module.args`, and evaluation dies with
`error: infinite recursion encountered`.

The error names `modulesPath` and suggests you referenced `config` in `imports`,
neither of which is the cause, so it blames the wrong thing. This has broken the
sibling branch twice, once from a Claude Code session that added 95 lines of
unwrapped generator output. If you add or regenerate a hardware config, wrap it
in the same commit:

```nix
{ ... }:
{ flake.modules.nixos.someHardware = { config, lib, modulesPath, ... }:
{
  # ... the original module body, unchanged
}
;}
```

### Module classes are not validated

flake-parts stamps the outer attribute name onto the module as `_class`
verbatim and checks nothing. A made-up class declares successfully and then
fails much later, at import, with
`cannot be imported into a module evaluation that expects class "nixos"`. Only
`nixos`, `homeManager`, `flake` and `generic` are meaningful; `darwin` works
because nix-darwin sets that `_class` itself.

The one mercy is that flake-parts also sets
`_file = "<flake>#modules.<class>.<name>"`, so the error names its own
declaration site.

### There are two different `config`s, and they shadow

Every file here has an outer flake-parts scope and an inner NixOS/HM module.
Both call their argument `config`, and they are **not the same thing**:

```nix
{ config, ... }:                       # flake-parts config: config.flake.modules.*
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.foo ];

    flake.modules.nixos.foo =
    { config, ... }:                   # NixOS config: config.services.*, config.nire.*
    {
        # the outer `config` is unreachable from in here
    };
}
```

A module written as a bare attrset (no `{ ... }:` line) has **no inner scope**,
so `config` inside it still means the flake-parts one. Adding an argument list
to reach the NixOS `config` silently changes what every existing `config` in
that module refers to. The fix is to bind what you need from the outer scope in
a `let` *before* the shadowing.

Four files here take `config` as a `perSystem` argument and will need this
treatment individually when the wrappers come off.

### `pkgs` from perSystem loses `allowUnfree`

perSystem's `pkgs` defaults to `inputs.nixpkgs.legacyPackages.<system>`, which
has no `nixpkgs.config` applied. This config installs plenty of unfree packages.
When unwrapping, `pkgs` belongs in the **deferred module's** argument list, where
it comes from the NixOS/HM evaluation, not in the outer scope. The same reasoning
is why host `nixosSystem` calls deliberately do not share a perSystem `pkgs`.

## Known defects

Seven, all confirmed by grep rather than inherited on trust. Full detail and
ordering in `PORT-PLAN.md`.

| file | defect |
|---|---|
| `nire/desktop-env/jovian/jovian.nix:49,63` | `adjustor` was removed from nixpkgs, folded into `handheld-daemon` |
| `nire/desktop-env/jovian/jovian.nix:11` | `inputs.jovian.decky-loader` — that flake exposes no such output |
| `nirePackages/editors/micro/micro.nix:7` | `flake.module` singular; declares nothing, so micro's config has never applied |
| `nire/shell-config/zsh/zsh.nix:171,198,207` | deprecated `initExtraFirst` / `initExtraBeforeCompInit` / `initExtra` |
| `nire/shell-config/bash/bash.nix:51` | hand-written `starship init bash` duplicating the HM integration |
| `nire/shell-config/zsh/` | powerlevel10k still present alongside starship |
| `nireHost/aspect-durandal.nix:34` | reads `flake.modules.elly`, which nothing declares |

The `flake.module` typo is the instructive one: it is valid Nix, evaluates
cleanly, and silently does nothing. That failure mode is the single real cost of
this whole architecture, and it is why the orphan check is worth porting early.

## Working in this repo

**`git add` before `nix eval`.** Flakes in a git repo ignore untracked files, so
a new module silently does not exist and you will debug a phantom. This wastes
time every session if forgotten.

**Read the generated dotfile, not just the module.** Most shell bugs here are
invisible in the `.nix` source and obvious in the output. Line numbers make
ordering and duplication questions answerable in one command. Every shell bug
found on the sibling branch was found this way.

**Read upstream source in the store rather than guessing at options.**
`nix build nixpkgs#<pkg>` works on darwin for most of these even though the host
is x86_64-linux, and grepping the result settles questions documentation leaves
ambiguous. This has repeatedly been worth it: ble.sh's `bleopt` defaults and
`ble-import` path resolution, home-manager's `useUserPackages` behaviour, and
flake-parts' `_class` stamping and `freeformType` placement were all settled from
source. In the `ble-import` case the source showed the `.bash` extension is
required for absolute paths, which would otherwise have silently broken every
import.

**Verify refactors by fingerprint, not by "it still evaluates."** For any change
meant to preserve behaviour, capture `toplevel.drvPath` before and after. But
identical drvPath is not the same as a correct mechanism — reordering module
imports permutes list-valued options like `environment.systemPackages`, which
changes the hash without changing the package set. Compare sets before concluding
a refactor broke something, and spot-check the values, not just the hash.

**Calibrate severity.** This is a homelab config, not production; the repo has
gone six months between commits. "This is broken and here is the fix" reads
better than incident-report framing.

## Conventions

**Formatting is deliberate.** The aligned-`=` columns throughout `modules/` are
intentional. Do not run a formatter casually, and match surrounding alignment
when editing. If treefmt gets ported, it should carry `flakeCheck = false` for
the same reason.

**Namespacing.** `nire` is the namespace for anything that does not need a more
specific tag; start broad and narrow as things clarify. `nireHost`, `nireUser`
and `nirePackages` are the more specific ones currently in use.

**Leave a grep trail when you make a name dynamic.** Turning `users.users.elly`
into `users.users.${config.nire.primaryUser}` makes the old string unfindable,
which is the real cost of the indirection. The convention — the user's own — is
to put the literal old form in a comment on the declaration so grepping it lands
somewhere instead of nowhere. Do the same for any future rename.

**`${...}` inside a Nix `''` string is Nix interpolation.** Writing
`${terminfo[khome]}` in what you intend as a comment is an evaluation error, not
a comment. Escape as `''${...}` or reword.

**`home.file.<n>.text` concatenates; it does not override.** The type is
`types.lines`, so two modules declaring the same file both contribute and the
result is the content twice over. In a dendritic layout this is easy to do by
accident, so give each generated file a single owning module.

**Check for an existing `programs.*` integration before hand-writing one.** The
`starship init bash` defect above is exactly this: the HM integration was already
enabled, and it is also better, since it uses the store path instead of relying
on `PATH`.

**Order in generated shell rc files is load-bearing and not obvious.** Home
Manager emits, in this order: `initContent` `mkBefore`, then `mkOrder 550`, then
`programs.zsh.plugins`, then unordered `initContent`. Anything that must run
after a plugin cannot live at 550. Later definitions also win, so an alias or
prompt init written by hand earlier in the file is silently overridden by the
nix-managed one later.

**VSCode settings.** Both `.vscode/` and `linux-flake/.vscode/` are tracked here.
On the sibling branch these were byte-identical copies and the nested one was
removed; worth checking they have not drifted before assuming either is live.

## Docs worth reading

- **`PORT-PLAN.md`** — the plan for finishing the migration. Read before changing
  anything structural.
- `git show flake-parts:SESSION-HANDOFF.md` — the sibling branch's notes on what
  is not recoverable from the tree: dead ends with their actual symptoms,
  load-bearing constraints, and decisions the user made that should not be
  silently relitigated.
- `git show flake-parts:SESSION-CHANGES.md` — its 37 commits, marked portable /
  file-addition / not-applicable.
- `git show flake-parts:linux-flake/flake-parts-reference.md` — the flake-parts
  machinery, with the upstream source backing each claim.
- `claude cave/port-prompt.md` — the kickoff prompt for this port. Note that its
  description of this branch as den-based is wrong; see `PORT-PLAN.md`.
