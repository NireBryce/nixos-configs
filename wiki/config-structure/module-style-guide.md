# Module style guide

_Last modified: 2026-10-28_

Every module under `flake/modules/` follows these conventions, not just
packages. See
[../meta/history.md](../meta/history.md) and [../meta/styleguide.md](../meta/styleguide.md) for why this file
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
- [Comment width](#comment-width)
- [The module header](#the-module-header)
- [An inner module lambda that uses no argument is `_:`](#an-inner-module-lambda-that-uses-no-argument-is-_)
- [`# summary:`, one per module](#-summary-one-per-module)
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

## Comment width

A pure `#` comment line wraps at 80 columns plus the line's own indentation —
a comment indented four spaces wraps at 84 — so the text after `# ` keeps one
width wherever the module nests it. This is the shape the tree already used;
the 2026-10-26 summary-comment insert landed past the wrap the surrounding
blocks used, and the sweep that fixed those added the checker.

`just comment-wrap` reports violations and exits nonzero on any;
`just comment-wrap --fix` rewrites the unambiguous prose (preview with
`--diff`). Skill `comment-wrap` is the procedure for what it declines.

The fixer reflows only prose. Left alone, and exempt from the rule: anything
inside a `''` or `"` string (`#` there is shell text — see "Rationale goes
inside the module body, not in a header block"); trailing comments after
code; URL lines; aligned `# ... # ...` tables; banner and `── section ──`
decoration lines; commented-out code and shell snippets; single tokens wider
than any wrapped line could hold (verbatim config spans sit like URLs).

`# summary:` is the one hand-tightened shape: it stays one line, so an
over-long one is shortened, never wrapped — the lead paragraph under it still
refills mechanically.

## The module header

A module names nothing: dirs-as-categories names it after its filename, and
the header comment says so ([module-files.md](module-files.md) has the
why; until 2026-10-16 every
module derived its name itself, with `moduleName = lib.removeSuffix ".nix"
(baseNameOf __curPos.file)` and `flake.modules.<class>.${moduleName} =`):

```nix
# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
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

## An inner module lambda that uses no argument is `_:`

`statix` flags a bare `{ ... }:` as its W10 "empty pattern" lint and suggests
`_:`, since nothing is destructured out of the argument. Write the inner
lambda of a module that takes nothing as `_:`:

```nix
nixos = _: {
    # ...
};
```

An older version of this page kept `{ ... }:` in `vm-networking.nix`,
`sunshine-elly.nix` and `sunshine.nix`, on the argument that it reads as "this
value is itself a module" where `_:` reads as "argument deliberately unused".
That was weighed and set aside: `_:` is equivalent, the lint ratchet
(`flake/scripts/lint-baseline.json`) counts statix findings and is now at 0
after those three were changed, so a new `{ ... }:` fails `just lint`.
Don't reintroduce it for readability; the key (`nixos`, `homeManager`,
`darwin`) already says it is a module.

## `# summary:`, one per module

Every module says what it is for in one `# summary:` comment, and has only
one. Where it goes depends on whether the module has a leading comment (the
block between the dirs-as-categories header and the opening `{`):

- **With a leading comment**, that comment's first line is the summary, and
  the paragraph it starts is the short version of everything below it:

  ```nix
  # summary: The setuid sudo binary is executable by `wheel` only (mode 4510,
  # root:wheel), so a service account or any other non-wheel user ... can't
  # reach sudo's own parser at all, ... (sudo-wheel-only.nix)
  {
      nixos = {
          security.sudo.execWheelOnly = true;
  ```

- **Without one**, a one-line `# summary:` is the first line of the class
  body, immediately inside it:

  ```nix
  nixos = {
      # summary: nix-ld, needed for VSCode remote connection, etc
      programs.nix-ld.enable = lib.mkDefault true;
  };
  ```
  (nix-ld.nix)

A module with several classes has one summary for the file, in the leading
comment. In `packages-config/` the prefix is `# package summary:`, always in
the body, and it says what the package is (not just its name or a URL):

```nix
homeManager = { pkgs, ... }: {
    # package summary: `rg` is a much faster and more powerful grep alternative
    home.packages = with pkgs; [
        ripgrep
    ];
};
```

Never write both a leading and a body summary: the two drift apart, and the
shorter one usually repeats the longer. 21 modules had both until 2026-10-26.
`just add-module` writes the body form; move it into the leading comment if
the module grows one. Keep a body summary to one line, inside the comment
width (above) — a too-long summary is tightened, not wrapped.

### Why it is a comment and not an option

The prefix looks like a placeholder for a field that will arrive. It is
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
a tree-wide edit for something already working; evaluation already refuses
repeated names; identical descriptions would still merge silently;
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

`just modules` fails on an orphan (`module-orphans` does not: it fails only when built, and `just check` is `--no-build`), reports untracked files, and checks drift.
