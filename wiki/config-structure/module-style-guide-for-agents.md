# Module style guide, for agents

_Last modified: 2026-10-28_

Condensed from [module-style-guide.md](module-style-guide.md). Rules only.

Applies to every module under `flake/modules/`, packages included.

## Contents

- [Counts](#counts)
- [The header](#the-header)
- [Formatting](#formatting)
- [`# summary:` / `# package summary:`](#-summary---package-summary)
- [`_:` for an inner module lambda that uses no argument](#_-for-an-inner-module-lambda-that-uses-no-argument)
- [Comments](#comments)
- [File placement produces no error when wrong](#file-placement-produces-no-error-when-wrong)

## Counts

Generated: `just wiki-gen` rewrites it, `just wiki-lint` fails when stale.
Never hand-edit. By hand it is
`grep -rl --include='*.nix' -- <pattern> flake/modules | wc -l`.

<!-- generated:module-counts -- from a count of the .nix files under flake/modules/, by `just wiki-gen`; change the source, not this table -->

| What | Files |
|---|---|
| total `.nix` files under `flake/modules/` | 248 |
| header comment (`# This is a dirs-as-categories module…`) | 232 |
| `# summary:` / `# package summary:` comment | 186 |
| `with pkgs;` package lists | 120 |

<!-- /generated -->

## The header

```nix
# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    homeManager = { pkgs, ... }: {
        ...
    };
}
```

Name = filename; nothing in the file names it ([module-files.md](module-files.md)).
Was `moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file)` +
`flake.modules.<class>.${moduleName} =` until 2026-10-16.

**Which argument goes where is not cosmetic:**

- `lib`, `inputs` → the **outer** list, only if used (deadnix); neither → no header.
- `pkgs`, `config` → the **inner** module's list. No outer `config` exists;
  `pkgs` from anywhere else is perSystem's, a different instance from the
  host's.

## Formatting

- Opening brackets on the same line as whatever causes them.
- Four-space indent. Top-level `let` / `in {` at column 0, level with the
  closing `}`; the body one level in.
- A nested `let` / `in` sits level with the line that opens it (lambda, `=`,
  `else`) and with the bracket closing the `in` expression, never a level
  deeper: an extra level with no closing bracket of its own reads as a
  missing bracket.
- `with pkgs; [ ... ]`, one package per line, no `pkgs.` prefix inside.
- **Aligned `=` columns** for runs of related assignments — match the
  surrounding block, don't apply it everywhere. **This is why `nix fmt` is
  not run**; `treefmt` is deliberately absent and would need
  `flakeCheck = false`.
- **Comment width: a pure `#` comment line wraps at 80 columns plus the
  line's own indent.** `just comment-wrap` reports and exits 1 on any;
  `--fix` rewrites prose only. Exempt: strings, trailing comments, URLs,
  aligned `# ... # ...` tables, banners, commented-out code/shell snippets,
  over-wide tokens. `# summary:` stays one line — tighten it, never wrap it
  (the lead under it refills mechanically). Procedure: skill `comment-wrap`.

## `# summary:` / `# package summary:`

One per module, never two. Module with a leading comment (between the header
and `{`): that comment's first line is `# summary:`. Without one: a one-line
`# summary:` first in the class body. Several classes: the leading comment.
`package summary:` in `packages-config/` (what the package *is*), always in
the body. `just add-module` writes the body form. Every summary stays one
line and inside the comment width — a too-long one is tightened, not
wrapped. Replaced `# # description = "..."`, 2026-10-26; 21 modules had
both forms until then.

**There is no such field** — not in flakes, flake-parts, or the NixOS module
system (checked). The module system has no per-module namespace at all. A
typed registry was considered and **declined**. Don't "upgrade" this to an
option without a reason beyond tidiness.

## `_:` for an inner module lambda that uses no argument

- Write `nixos = _: { ... };`, not `{ ... }:`. statix W10 flags the latter and
  `lint-baseline.json` is at 0, so a new one fails `just lint`. The earlier
  "`{ ... }:` signals a module" exception (`vm-networking.nix`,
  `sunshine-elly.nix`, `sunshine.nix`) was removed in `23c7b89`.

## Comments

- Rationale goes **inside the module body**, next to the option it concerns —
  not in a header block above the argument list.
- **`#` inside a `''` string is shell text, not a Nix comment.** It is
  emitted verbatim into the generated dotfile. Notes for the `.nix` editor go
  *above* the string.
- **When a rename makes the old name ungreppable, say what it was** on the
  declaration — one line containing the old string, so a search lands there.
  Live examples: `boot-durandal.nix`, `enable-home-manager.nix`.
- **A bug recorded in a comment stays in the file.** If a later change
  strands it, move it to a `history` section at the bottom and *expand* it —
  it can no longer lean on its surrounding context.

## File placement produces no error when wrong

- A category includes **every module under its folder**, any depth. A
  folder is a category when a subfolder holds modules (or
  `folderIsCategory = true`); adding a first subfolder can promote a folder.
  Keep a module out -> file it outside the tree.
- Entry points sit outside every category: `hosts.nix`,
  `durandal-configuration.nix`, `elly-home-manager.nix`.
- Filename = name. A repeated name, or one shared with a category, stops
  evaluation (was a silent merge, §34).

`just check` fails on an orphan (`checkOrphans = "eval"`, so `--no-build` fails too); `just modules` reports untracked files and checks drift.
