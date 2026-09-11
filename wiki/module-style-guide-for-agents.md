# Module style guide, for agents

_Last modified: 2026-09-11_

Condensed from [module-style-guide.md](module-style-guide.md), which keeps
the reasoning and the declined alternatives. Rules only.

Applies to every module under `flake/modules/`, not just packages.

## Counts

Every count module-style-guide.md used to state inline, in the one place
the `counts` subcheck of `wiki/scripts/check_wiki.py` watches — moved here
2026-09-11. Recompute by hand with
`grep -rl --include='*.nix' -- <pattern> flake/modules | wc -l`.

| What | Files |
|---|---|
| total `.nix` files under `flake/modules/` | 262 |
| module header (`moduleName = lib.removeSuffix ...`) | 212 |
| `# # description` as first body line | 20 |
| `with pkgs;` package lists | 119 |

## The header

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

**Which argument goes where is not cosmetic:**

- `lib`, `inputs` → the **outer** (flake-parts) list.
- `pkgs`, `config` → the **inner** module's list. `pkgs` from the outer scope
  is perSystem's, with no `nixpkgs.config` applied — it silently loses
  `allowUnfree`. `config` from the outer scope is the flake-parts config, not
  the NixOS/HM one.

## Formatting

- Opening brackets on the same line as whatever causes them.
- Four-space indent. Module bodies sit one level deeper than necessary;
  reindenting risks the `''` strings in the shell modules, so leave it.
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
  emitted verbatim into the generated dotfile; fourteen lines of maintenance
  notes once shipped into `~/.zshrc` this way. Notes for the `.nix` editor go
  *above* the string.
- **When a rename makes the old name ungreppable, say what it was** on the
  declaration — one line containing the old string, so a search lands there.
  Live examples: `boot-durandal.nix`, `enable-home-manager.nix`.
- **A bug recorded in a comment stays in the file.** If a later change
  strands it, move it to a `history` section at the bottom and *expand* it —
  it can no longer lean on its surrounding context.

## File placement produces no error when wrong

- A category collects from its **subdirectories only**. A `.nix` file
  directly in a category directory is collected by nothing.
- Entry points sit outside every category tree: `checks.nix`, `hosts.nix`,
  `durandal-configuration.nix`, `elly-home-manager.nix`.
- A filename becomes the attribute name, and names **merge** rather than
  conflict — a file named the same as a category silently combines with it.

`just modules` checks the last two.

## See also

[module-style-guide.md](module-style-guide.md) ·
[conventions.md](conventions.md) · [styleguide.md](styleguide.md) (the
wiki's own house style, a different thing)
