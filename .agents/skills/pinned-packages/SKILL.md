---
name: pinned-packages
description: How to keep the hand-pinned upstream packages current, and retire each pin once nixpkgs or llm-agents packages it.
---

# Tending the hand-pinned packages

## Applies to

- "Are the pins current / bump the pins / update polytoken or
  zai-coding-helper" — or any pass looking for out-of-date packages, since
  these are the only packages a `nix flake update` never moves.
- Adding a **new** package fetched straight from upstream with a hand-written
  version and hash: register it in `PINS` in
  `flake/scripts/pinned-packages.py` in the same change (see "Adding a pin").

Not for:

- Packages from nixpkgs, llm-agents, or any other flake input. Those move
  with `nix flake update`; lagging upstream there is nixpkgs' business, not
  a pin here.
- Homebrew entries in `homebrew.nix`. `brew` floats them itself.

The pins, as of this skill's writing (the script's `PINS` table is the live
list):

| Pin | Module | Tracks |
|---|---|---|
| `polytoken` | `packages-config/development/tools/ai-tools/polytoken.nix` | `stable` in `https://dl.polytoken.dev/channels.json` |
| `zai-coding-helper` | `packages-config/development/tools/ai-tools/zai-coding-helper.nix` (+ its trimmed `-package.json`, `-package-lock.json`) | npm `latest` dist-tag of `@z_ai/coding-helper` |

## Why this exists

2026-09-28: a sweep for out-of-date packages found both pins behind. polytoken
was on 0.7.4 with stable at 0.8.13, and zai-coding-helper on
0.1.0-beta.1 with 0.1.1 out. Worse, polytoken's pinned URL (the raw binary)
and its published `SHA256SUMS` files had both started returning 404, so the
pin only built while the old binary sat in the local store. Nothing flags a
stale pin. `nix flake update` doesn't touch it and eval stays green, so it
rots until a fresh machine or a GC turns it into a build failure.

## Procedure

1. **Check.** From anywhere in the repo:

   ```sh
   just pinned-packages          # = just pinned-packages check
   ```

   Per pin, one line with `pinned`, `upstream`, and `current`/`BUMP`, plus
   a `packaged in …` line for every nixpkgs or llm-agents attribute whose
   name matches the pin. Both inputs are searched at the flake's **locked**
   rev and at their branch **head**. Exits 1 if anything wants action.

2. **If a `packaged in` line appears, retire the pin instead of bumping it.**
   A name match is a candidate, not proof, so read the package first
   (`nix eval` its `meta.homepage`, `version`, `meta.mainProgram`):
   - Same program, version ≥ the pin: replace the hand-built derivation with
     the packaged one. llm-agents is reached as
     `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.<name>`
     (`zcode.nix` is the worked example, and needs `inputs` in the outer
     argument list). Delete the pin's extra files (for zai: both trimmed JSON
     files). Remove the pin's entry from `PINS`, and its tests from
     `test_pinned_packages.py`.
   - Found at **head** only: `just update` (or `nix flake update <input>`)
     first, so the locked rev has it.
   - Keep the module's history: move the retired pin's reasoning to a
     `# ── history ──` heading at the bottom (AGENTS.md, "A bug recorded in
     a comment stays in the file").
   - Also check for Homebrew overlap on lysithea: `just available <attr>`
     (skill `package-platform-support`).

3. **Otherwise, bump.**

   ```sh
   just pinned-packages bump --all          # or: bump polytoken
   ```

   It rewrites the version and hashes in place, builds the pin through this
   host's evaluated Home Manager config, and prints `<binary> --version`.
   - **polytoken**: one fetchzip hash per platform (four zips, ~40 MB each).
     Upstream publishes no checksum now, so this is trust-on-first-download.
     A hash that later changes for the **same** version means upstream
     re-cut the release, or worse. Stop and tell the user; don't just
     re-bump.
   - **zai-coding-helper**: regenerates the trimmed `package.json` (upstream's
     minus `devDependencies`) and the lockfile with `npm install
     --package-lock-only`, then recomputes `npmDepsHash`. node and
     prefetch-npm-deps come from the flake's own nixpkgs via `nix shell`.
     Nothing needs to be on PATH.

4. **Read the diff.** For polytoken, expect `version` and four hashes. For
   zai, expect `version`, `hash`, `npmDepsHash` and a lockfile diff. A
   lockfile that suddenly grows by hundreds of lines has pulled in
   devDependencies, which the tests catch. A new major version is worth a
   glance at upstream's changelog before shipping.

5. **Verify and ship.** `just pinned-packages-test` (also in `preflight`).
   The bump already built the pin on this host. Ship via skill `ship`.
   Building on lysithea is only needed if the change touched the darwin
   path itself, not for a plain bump.

## Traps

- **`nix store prefetch-file --unpack` is the wrong hash for polytoken.**
  For its single-file zip it disagrees with `fetchzip { stripRoot = false; }`
  (the first bump on 2026-09-28 failed exactly so). The script reads
  fetchzip's own `got:` line from a fake-hash build instead. Don't
  "simplify" that back.
- **The rewrites are regexes over the modules' exact shapes**:
  `version = "…";` once, `urlPlatform = "…"; hash = "…";` on one line per
  platform, and `hash =` / `npmDepsHash =` once each in the zai module. Reshape
  a module and `test_pinned_packages.py`'s `CommittedModules` fails. Fix
  the regex or the module, not the test.
- **polytoken's docs page and installer still name the raw binaries and
  `SHA256SUMS.*`**, which have been 404 since at least 2026-09-28. Trust
  what `dl.polytoken.dev` actually serves, and don't infer URLs from the docs.
- **The check can't prove absence.** No `packaged in` line only means no
  attribute name matched the pin's `pattern`. If a tool gets packaged under
  an unrelated name, the check misses it. Widen `pattern` when you learn
  of one.

## Adding a pin

1. Give the module a single `version = "…";` line and hashes in a shape a
   regex can own. Copy polytoken's table or zai's field names rather than
   inventing a third shape.
2. Add an entry to `PINS` (module, attribute-name `pattern`, binary for
   the `--version` check). Add an upstream-version function to `UPSTREAM`
   and a bump function to `BUMP`.
3. Add fixture and committed-module tests beside the existing ones in
   `test_pinned_packages.py`.
4. Point the module's comment at `just pinned-packages bump <name>`
   rather than describing a manual bump.

## See also

- `flake/scripts/pinned-packages.py` — its docstring covers the check and
  bump semantics in more detail.
- Skill `new-package` — adding a package at all. This skill only applies
  once the package has to be pinned by hand.
- Skill `package-platform-support` — darwin buildability and Homebrew
  overlap, for when a pin retires onto a packaged attribute.
