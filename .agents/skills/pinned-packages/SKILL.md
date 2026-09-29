---
name: pinned-packages
description: How to keep the hand-pinned upstream packages current, and retire each pin once nixpkgs or llm-agents packages it.
---

# Tending the hand-pinned packages

## Applies to

- "Are the pins current / bump the pins / update polytoken or
  zai-coding-helper", or any out-of-date-package pass — these are the only
  packages `nix flake update` never moves.
- Adding a **new** package fetched from upstream with a hand-written version
  and hash: register it in `PINS` in `flake/scripts/pinned-packages.py` in
  the same change ("Adding a pin").

Not for: packages from nixpkgs, llm-agents, or any flake input (they move
with `nix flake update`; lag is upstream's business), or Homebrew entries in
`homebrew.nix` (`brew` floats them).

Pins as of writing (the script's `PINS` table is live):

| Pin | Module | Tracks |
|---|---|---|
| `polytoken` | `packages-config/development/tools/ai-tools/polytoken.nix` | `stable` in `https://dl.polytoken.dev/channels.json` |
| `zai-coding-helper` | `packages-config/development/tools/ai-tools/zai-coding-helper.nix` (+ trimmed `-package.json`, `-package-lock.json`) | npm `latest` dist-tag of `@z_ai/coding-helper` |

## Why

2026-09-28 sweep: polytoken 0.7.4 vs stable 0.8.13; zai-coding-helper
0.1.0-beta.1 vs 0.1.1. polytoken's pinned raw-binary URL and `SHA256SUMS`
files were 404, so the pin built only while the old binary sat in the local
store. Nothing flags a stale pin (eval stays green); it rots until a fresh
machine or GC makes it a build failure.

## Procedure

1. **Check:** `just pinned-packages` (= `check`). Per pin: `pinned`,
   `upstream`, `current`/`BUMP`, plus a `packaged in …` line for every
   nixpkgs/llm-agents attribute whose name matches, searched at the
   **locked** rev and branch **head**. Exits 1 if action is needed.

2. **`packaged in` appears: retire, don't bump.** A name match is a
   candidate; read the package first (`nix eval` `meta.homepage`, `version`,
   `meta.mainProgram`).
   - Same program, version >= pin: replace the hand-built derivation.
     llm-agents:
     `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.<name>`
     (`zcode.nix` is the example; needs `inputs` in the outer args). Delete
     the pin's extra files (zai: both trimmed JSONs), its `PINS` entry, and
     its tests in `test_pinned_packages.py`.
   - At **head** only: `just update` (or `nix flake update <input>`) first.
   - Move the retired pin's reasoning to a `# ── history ──` heading at the
     bottom (AGENTS.md, "A bug recorded in a comment stays in the file").
   - Check Homebrew overlap on lysithea: `just available <attr>` (skill
     `package-platform-support`).

3. **Otherwise bump:** `just pinned-packages bump --all` (or `bump polytoken`).
   Rewrites version and hashes in place, builds the pin through this host's
   evaluated HM config, prints `<binary> --version`.
   - **polytoken**: one fetchzip hash per platform (four ~40 MB zips).
     Upstream publishes no checksum: trust-on-first-download. A hash that
     changes for the **same** version means upstream re-cut the release, or
     worse — stop and tell the user; don't re-bump.
   - **zai-coding-helper**: regenerates the trimmed `package.json`
     (upstream's minus `devDependencies`) and lockfile via `npm install
     --package-lock-only`, recomputes `npmDepsHash`. node and
     prefetch-npm-deps come from the flake's nixpkgs via `nix shell`.

4. **Read the diff.** polytoken: `version` + four hashes. zai: `version`,
   `hash`, `npmDepsHash`, lockfile diff. A lockfile growing by hundreds of
   lines pulled in devDependencies (tests catch it). Glance at upstream's
   changelog on a new major.

5. **Verify and ship:** `just pinned-packages-test` (also in `preflight`);
   the bump already built the pin here. Ship via skill `ship`. Build on
   lysithea only if the darwin path itself changed.

## Traps

- **`nix store prefetch-file --unpack` gives the wrong hash for polytoken**:
  for its single-file zip it disagrees with `fetchzip { stripRoot = false; }`
  (first bump, 2026-09-28, failed so). The script reads fetchzip's own `got:`
  line from a fake-hash build. Don't "simplify" it back.
- **Rewrites are regexes over the modules' exact shapes**: `version = "…";`
  once, `urlPlatform = "…"; hash = "…";` on one line per platform, `hash =` /
  `npmDepsHash =` once each in zai. Reshaping a module fails
  `test_pinned_packages.py`'s `CommittedModules`; fix the regex or module,
  not the test.
- **polytoken's docs and installer still name the raw binaries and
  `SHA256SUMS.*`** (404 since at least 2026-09-28). Trust what
  `dl.polytoken.dev` serves; don't infer URLs from docs.
- **The check can't prove absence**: no `packaged in` line only means no
  attribute name matched the pin's `pattern`. Widen `pattern` when you learn
  of an unrelated-name package.

## Adding a pin

1. Give the module a single `version = "…";` line and regex-ownable hashes;
   copy polytoken's table or zai's field names.
2. Add to `PINS` (module, attribute-name `pattern`, binary for `--version`),
   an upstream-version function in `UPSTREAM`, a bump function in `BUMP`.
3. Add fixture and committed-module tests in `test_pinned_packages.py`.
4. Point the module's comment at `just pinned-packages bump <name>`, not a
   manual bump.

See also: `flake/scripts/pinned-packages.py` docstring; skill `new-package`
(adding a package at all); skill `package-platform-support` (darwin and
Homebrew overlap when a pin retires).
