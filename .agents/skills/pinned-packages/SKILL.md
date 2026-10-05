---
name: pinned-packages
description: How to keep the hand-pinned upstream packages current, and retire each pin once nixpkgs or llm-agents packages it.
when_to_use: Asked "are the pins current", "bump the pins", "update zai-coding-helper", adding a package fetched with a hand-written version and hash.
---

# Tending the hand-pinned packages

## Applies to

- "Are the pins current / bump the pins / update zai-coding-helper", or any
  out-of-date-package pass — these are the only packages `nix flake update`
  never moves.
- Adding a **new** package fetched from upstream with a hand-written version
  and hash: register it in `PINS` in `flake/scripts/pinned-packages.py` in
  the same change ("Adding a pin").

Not for: packages from nixpkgs, llm-agents, or any flake input (they move
with `nix flake update`; lag is upstream's business), or Homebrew entries in
`homebrew.nix` (`brew` floats them).

Pins as of writing (the script's `PINS` table is live):

| Pin | Module | Tracks |
|---|---|---|
| `zai-coding-helper` | `packages-config/development/tools/ai-tools/zai-coding-helper.nix` (+ trimmed `-package.json`, `-package-lock.json`) | npm `latest` dist-tag of `@z_ai/coding-helper` |

## Why

2026-09-28 sweep: polytoken 0.7.4 vs stable 0.8.13; zai-coding-helper
0.1.0-beta.1 vs 0.1.1. polytoken's pinned raw-binary URL and `SHA256SUMS`
files were 404, so the pin built only while the old binary sat in the local
store. Nothing flags a stale pin (eval stays green); it rots until a fresh
machine or GC makes it a build failure.

2026-10-05: polytoken removed outright — still unpackaged anywhere, no
longer wanted. Its pin went out at 0.8.16 against stable 0.8.18, never
bumped; the module's fetch/history reasoning is in git history
(`polytoken.nix`, deleted).

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

3. **Otherwise bump:** `just pinned-packages bump --all` (or `bump
   zai-coding-helper`). Rewrites version and hashes in place, builds the pin
   through this host's evaluated HM config, prints `<binary> --version`.
   - **zai-coding-helper**: regenerates the trimmed `package.json`
     (upstream's minus `devDependencies`) and lockfile via `npm install
     --package-lock-only`, recomputes `npmDepsHash`. node and
     prefetch-npm-deps come from the flake's nixpkgs via `nix shell`.

4. **Read the diff.** zai: `version`, `hash`, `npmDepsHash`, lockfile diff.
   A lockfile growing by hundreds of lines pulled in devDependencies (tests
   catch it). Glance at upstream's changelog on a new major.

5. **Verify and ship:** `just pinned-packages-test` (also in `preflight`);
   the bump already built the pin here. Ship via skill `ship`. Build on
   lysithea only if the darwin path itself changed.

## Traps

- **For a single-file zip, `nix store prefetch-file --unpack` can compute a
  different NAR hash than the fetch in the module** — it disagreed with
  `fetchzip { stripRoot = false; }` for the retired polytoken pin (first
  bump, 2026-09-28, shipped a hash the build then rejected). Ask the module's
  own fetcher instead: a fake-hash build's `got:` line is the hash that fetch
  will check against.
- **Rewrites are regexes over the modules' exact shapes**: `version = "…";`
  once, each regex-owned hash on one line (zai: `hash =` / `npmDepsHash =`).
  Reshaping a module fails `test_pinned_packages.py`'s `CommittedModules`;
  fix the regex or module, not the test.
- **The check can't prove absence**: no `packaged in` line only means no
  attribute name matched the pin's `pattern`. Widen `pattern` when you learn
  of an unrelated-name package.

## Adding a pin

1. Give the module a single `version = "…";` line and regex-ownable hashes;
   copy zai's field names (a retired pin's module in git history — polytoken,
   2026-10-05 — is a second worked example).
2. Add to `PINS` (module, attribute-name `pattern`, binary for `--version`),
   an upstream-version function in `UPSTREAM`, a bump function in `BUMP`.
3. Add fixture and committed-module tests in `test_pinned_packages.py`.
4. Point the module's comment at `just pinned-packages bump <name>`, not a
   manual bump.

See also: `flake/scripts/pinned-packages.py` docstring; skill `new-package`
(adding a package at all); skill `package-platform-support` (darwin and
Homebrew overlap when a pin retires).
