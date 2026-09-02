# Module style guide

## Contents

- [Opening brackets go on the same line as whatever causes them](#opening-brackets-go-on-the-same-line-as-whatever-causes-them)
- [Four-space indent](#four-space-indent)
- [The module header — 151 of 151 files](#the-module-header--151-of-151-files)
- [`# # description = "..."` as the first line of the body — 70 files](#--description---as-the-first-line-of-the-body--70-files)
- [Rationale goes inside the module body, not in a header block](#rationale-goes-inside-the-module-body-not-in-a-header-block)
- [`with pkgs; [ ... ]` for package lists — 106 files](#with-pkgs----for-package-lists--106-files)
- [Aligned `=` columns](#aligned--columns)
- [When a rename makes the old name ungreppable, say what it was](#when-a-rename-makes-the-old-name-ungreppable-say-what-it-was)
- [A bug recorded in a comment stays in the file](#a-bug-recorded-in-a-comment-stays-in-the-file)
- [File placement is load-bearing](#file-placement-is-load-bearing)

Conventions for `flake/modules/`. Counts are from the tree as of
2026-08-08, so "how many files do this" is checkable rather than asserted.

This file used to live at `modules/nirePackages/style-guide.md`, where its
location implied it governed only package modules, and later at `claude
cave/claude-style-guide.md` until that directory was retired 2026-09-02. It
applies to every module — see [history.md](history.md) and
[styleguide.md](styleguide.md) for why it counts as an exception to this
wiki's usual "index over restatement" rule.

---

## Opening brackets go on the same line as whatever causes them

The original rule, and the only one that is purely about looks. It reduces
clutter and makes brackets easier to match by eye when debugging.

```nix
{
    let
        x = y;
    in {
        flake.modules.homeManager.myModule = {
            x;
        };
    };
}
```

## Four-space indent

Consistent across the tree. Module bodies currently sit one level deeper than
they strictly need to, left over from moving `flake.modules` out of `perSystem`
without reflowing — reindenting would risk the `''` strings in the shell
modules, so it was left alone.

## The module header — 151 of 151 files

Every module derives its own name from its filename rather than repeating it:

```nix
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            ...
        };
}
```

Which argument goes where is not cosmetic:

- `lib` and `inputs` belong in the **outer** (flake-parts) list.
- `pkgs` and `config` belong in the **inner** module's list. `pkgs` taken from
  the outer scope is perSystem's, which has no `nixpkgs.config` applied and
  would silently lose `allowUnfree`; `config` from the outer scope is the
  flake-parts config, not the NixOS/HM one.

`CLAUDE.md` has the two-`config` shadowing trap in full.

## `# # description = "..."` as the first line of the body — 70 files

A one-line description of what the module is for, commented out, immediately
inside the module body:

```nix
flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
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

A typed registry (`flake.moduleDescriptions.${moduleName}`, `attrsOf str`)
would be queryable and would **error** on two modules setting the same key
differently, catching the module-name collision class for free. Declined:
70 files to edit for something working; `just modules` already detects
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

## `with pkgs; [ ... ]` for package lists — 106 files

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
home.stateVersion   = lib.mkDefault "22.11";
home.username       = lib.mkDefault "elly";
home.homeDirectory  = lib.mkDefault "/home/elly";  # Darwin is different
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
# merged with the `nire/boot/` category of the same name
```

```nix
# the full path here is `home-manager.users.elly`; the account name is
# hardcoded, as it is in users.users.elly and home.username
```

Both live in the tree: `nireHost/durandal/hardware/boot-durandal.nix` and
`nire/system/home-manager/enable-home-manager.nix`.

## A bug recorded in a comment stays in the file

Commit messages hold the fuller account, but nobody finds them. If a later
change strands the comment — its code is gone, or the name it explained has
changed — move it to a `history` section at the bottom of the file rather than
deleting it, and expand it, since it can no longer lean on the context it sat
next to. `boot-durandal.nix` has one. See `CLAUDE.md` for the rule in full.

## File placement is load-bearing

Not formatting, but it belongs here because getting it wrong produces no error:

- A category collects from its **subdirectories only**. A `.nix` file placed
  directly in a category directory is collected by nothing.
- Entry points — `checks.nix`, `hosts.nix`, `durandal-configuration.nix`,
  `elly-home-manager.nix` — sit outside every category tree deliberately.
- A module's filename becomes its attribute name, and names **merge** rather
  than conflicting, so a file named the same as a category silently combines
  with it.

`just modules` checks the last two.
