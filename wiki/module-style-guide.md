# Module style guide

_Last modified: 2026-10-20_

Every module under `flake/modules/` follows these conventions, not just
packages. See
[history.md](history.md) and [styleguide.md](styleguide.md) for why this file
is an exception to the wiki's "index over restatement" rule.

File counts live in one table in
[module-style-guide-for-agents.md](module-style-guide-for-agents.md#counts).
`just wiki-gen` writes it from the tree and `just wiki-lint` fails when it is
stale. (The inline per-section counts this replaced, dated 2026-08-08, were
all false by 2026-09-09: the tree had grown from 151 to 263 files.)

> **Condensed version:**
> [module-style-guide-for-agents.md](module-style-guide-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Opening brackets go on the same line as whatever causes them](#opening-brackets-go-on-the-same-line-as-whatever-causes-them)
- [Four-space indent](#four-space-indent)
- [The module header](#the-module-header)
- [`{ ... }:` on an inner module lambda is sometimes deliberate](#---on-an-inner-module-lambda-is-sometimes-deliberate)
- [`# # description = "..."` as the first line of the body](#--description---as-the-first-line-of-the-body)
- [Rationale goes inside the module body, not in a header block](#rationale-goes-inside-the-module-body-not-in-a-header-block)
- [`with pkgs; [ ... ]` for package lists](#with-pkgs----for-package-lists)
- [Aligned `=` columns](#aligned--columns)
- [When a rename makes the old name ungreppable, say what it was](#when-a-rename-makes-the-old-name-ungreppable-say-what-it-was)
- [A bug recorded in a comment stays in the file](#a-bug-recorded-in-a-comment-stays-in-the-file)
- [File placement is load-bearing](#file-placement-is-load-bearing)

## Opening brackets go on the same line as whatever causes them

The original rule, and the only one that is purely about looks. It reduces
clutter and makes brackets easier to match by eye when debugging.

```nix
{ lib, ... }:
let
    x = y;
in {
    homeManager = {
        inherit x;
    };
}
```

## Four-space indent

Consistent across the tree. The top-level `let` and `in {` sit at column 0,
level with the closing `}`, and the module body one level in. Until
2026-10-08 the `let ... in` block sat one level deeper than its closing `}`,
left over from moving `flake.modules` out of `perSystem` without reflowing;
the reflow dedented every line uniformly, which leaves `''` strings' content
unchanged (every host's toplevel drvPath was identical before and after).

The same goes for a nested `let`: `let` and `in` sit level with the line
that opens them (a module lambda, an `=`, an `else`), and so does the bracket
that closes the `in` expression:

```nix
    nixos = { pkgs, ... }:
    let
        x = y;
    in {
        ...
    };
```

Indenting the `let` a level deeper makes `in {` open an indentation level
whose closing bracket sits a level further out, and a reader skimming the
file sees a level with no bracket closing it and suspects one is missing.

## The module header

A module names nothing: dirs-as-categories names it after its filename, and
the first-line comment says so ([module-files.md](module-files.md) has the
why; until 2026-10-16 every
module derived its name itself, with `moduleName = lib.removeSuffix ".nix"
(baseNameOf __curPos.file)` and `flake.modules.<class>.${moduleName} =`):

```nix
# dirs-as-categories: the module is named after this file; its categories are the folders above it
{ lib, ... }:
{
    homeManager = { pkgs, ... }: {
        ...
    };
}
```

Which argument goes where is not cosmetic:

- `lib` and `inputs` belong in the **outer** list, and only the ones the file
  uses (deadnix fails an unused one); a file using neither has no header.
- `pkgs` and `config` belong in the **inner** module's list. There is no outer
  `config` any more (a module file can't ask for one), and `pkgs` from
  anywhere else would be perSystem's, which has no `nixpkgs.config` applied
  and would silently lose `allowUnfree`.

## `{ ... }:` on an inner module lambda is sometimes deliberate

`statix` flags a bare `{ ... }:` as its W10 "empty pattern" lint and suggests
`_:` instead, since nothing is destructured out of the argument. Usually
correct — but three modules keep `{ ... }:` on purpose, as a readability
signal that the value being assigned is itself a NixOS module (something
that will in turn receive `config`/`lib`/`pkgs`/etc., even though this
particular one doesn't use any of them), not just an ignored argument:

```nix
nixos = { ... }: {
    # ...
};
```

`_:` is technically equivalent and shorter, but reads as "argument
deliberately unused" with no hint of what kind of function this is — the
distinction that matters when skimming a file to tell "is this a module" from
"is this a plain function". Left alone in `vm-networking.nix`,
`sunshine-elly.nix`, and `sunshine.nix`; the corresponding statix findings are
accepted into `lint-baseline.json` rather than fixed. Don't "fix" these on a
lint pass without checking here first.

## `# # description = "..."` as the first line of the body

A one-line description of what the module is for, commented out, immediately
inside the module body:

```nix
homeManager = { pkgs, ... }: {
    # # description = "`rg` is a much faster and more powerful grep alternative";
    home.packages = with pkgs; [
        ripgrep
    ];
};
```

Keep it first, keep it to one line.

### Why it is a comment and not an option

The doubled `#` looks like a placeholder for a field that will arrive. It is
not. **There is no such field, in flakes, in flake-parts, or in the NixOS
module system** (checked, not assumed: flake-parts declares no module-
metadata option; `extras/modules.nix` attaches only `_class` and `_file`;
NixOS `meta.doc` is a path for the docs build, not a string; `lib/modules.nix`
carries `_file`/`_class`/`key` and nothing else). Structurally, **the module
system has no per-module namespace** — every module's `config` merges into
one tree, so a description mechanism has to be a registry keyed by module
name living outside the modules, which is what this comment already is,
informally.

### The alternative that was considered and declined

A typed registry (`flake.moduleDescriptions.<name>`, `attrsOf str`)
would be queryable and would **error** on two modules setting the same key
differently, catching the module-name collision class for free. Declined:
a tree-wide edit for something already working; `just modules` already detects
collisions for all names; identical descriptions would still merge silently;
one more `unknown flake output` warning; and a registry can go stale
silently. **Do not "upgrade" this to an option without a reason beyond
tidiness.**

## Rationale goes inside the module body, not in a header block

Comments explaining *why* sit within the module they explain, next to the option
they concern. Do not open a file with a long explanatory block above the
argument list.

One real exception: **`#` inside a `''` string is shell text, not a Nix
comment.** Anything written inside `initContent`, `.blerc` and friends is
emitted verbatim into the generated dotfile — fourteen lines of maintenance
notes once shipped into `~/.zshrc` this way. Notes meant for whoever edits the
`.nix` go *above* the string, where they are Nix comments.

## `with pkgs; [ ... ]` for package lists

```nix
home.packages = with pkgs; [
    ripgrep
    fd
];
```

One package per line, no `pkgs.` prefix inside the `with`.

## Aligned `=` columns

Used where a run of related assignments reads better as a column:

```nix
home = {
    stateVersion   = lib.mkDefault "22.11";
    username       = lib.mkDefault "elly";
    homeDirectory  = lib.mkDefault "/home/elly";  # Darwin is different
};
```

Not applied everywhere — it is for runs of related settings, not every
assignment in the tree. Match whatever the surrounding block does.

**This is why `nix fmt` is not run.** A formatter flattens these columns across
every file. `treefmt` is deliberately absent; if it is ever added it needs
`flakeCheck = false`.

## When a rename makes the old name ungreppable, say what it was

Renaming a file changes its module name, and turning a literal into an
interpolation removes the string entirely — either way the old form stops
turning up in a search, which is the real cost of the change. Put the old form
in a short comment on the declaration. One line, no ceremony; it only has to
contain the string so a search lands here.

```nix
# renamed from `boot.nix`, which declared `flake.modules.nixos.boot` and so
# merged with the `general-config/boot/` category of the same name
```

```nix
# the full path here is `home-manager.users.elly`; the account name is
# hardcoded, as it is in users.users.elly and home.username
```

Both live in the tree: `host-config/durandal/hardware/boot-durandal.nix` and
`general-config/system/home-manager/enable-home-manager.nix`.

## A bug recorded in a comment stays in the file

Commit messages hold the fuller account, but nobody finds them. If a later
change strands the comment — its code is gone, or the name it explained has
changed — move it to a `history` section at the bottom of the file rather than
deleting it, and expand it, since it can no longer lean on the context it sat
next to. `boot-durandal.nix` has one. See `CLAUDE.md` for the rule in full.

## File placement is load-bearing

Not formatting, but it belongs here because getting it wrong produces no error:

- A category includes **every module under its folder**, at any depth. A
  folder becomes a category by holding a subfolder of modules, so adding the
  first subfolder to a flat folder can make it one (and reorder hosts'
  package lists); [module-files.md](module-files.md) has the rule and
  `folderIsCategory`. To keep a module out of a category, file it outside
  that category's tree.
- Entry points — `hosts.nix`, `durandal-configuration.nix`,
  `elly-home-manager.nix` — sit outside every category deliberately.
- A module's filename is its name. A file named like another module or a
  category stops evaluation (it used to merge silently, §34).

`just check` fails on an orphan (`module-orphans`); `just modules` reports untracked files.
