# Module style guide, for agents

_Last modified: 2026-10-20_

Condensed from [module-style-guide.md](module-style-guide.md). Rules only.

Applies to every module under `flake/modules/`, packages included.

## Counts

Generated: `just wiki-gen` rewrites it, `just wiki-lint` fails when stale.
Never hand-edit. By hand it is
`grep -rl --include='*.nix' -- <pattern> flake/modules | wc -l`.

<!-- generated:module-counts -- from a count of the .nix files under flake/modules/, by `just wiki-gen`; change the source, not this table -->

| What | Files |
|---|---|
| total `.nix` files under `flake/modules/` | 236 |
| header comment (`# dirs-as-categories: …`) | 227 |
| `# # description` as first body line | 35 |
| `with pkgs;` package lists | 115 |

<!-- /generated -->

## The header

```nix
# dirs-as-categories: the module is named after this file; its categories are the folders above it
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
  `pkgs` from anywhere else is perSystem's, with no `nixpkgs.config` applied
  — it silently loses `allowUnfree`.

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

## `# # description = "..."`

One commented line, first thing in the module body, one line only.

**There is no such field** — not in flakes, flake-parts, or the NixOS module
system (checked). The module system has no per-module namespace at all. A
typed registry was considered and **declined**. Don't "upgrade" this to an
option without a reason beyond tidiness.

## Don't "fix" these

- **`{ ... }:` on an inner module lambda** is deliberate in
  `vm-networking.nix`, `sunshine-elly.nix`, `sunshine.nix` — it signals "this
  value is itself a NixOS module", which `_:` doesn't. statix's W10 findings
  for them are accepted into `lint-baseline.json`.

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

`just check` fails on an orphan (`module-orphans`); `just modules` reports untracked files.
