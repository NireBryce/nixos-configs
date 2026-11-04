---
name: new-flake-input
description: Adds an external flake as an input and wires a build-time check from it, so the check really runs in preflight and CI.
when_to_use: Adding an entry to the flake inputs, consuming another flake's package or check, or bumping such an input.
---

# Adding an external flake input

**Needs:** bash-guards

## Applies to

A new `inputs.<name>` in `flake/flake.nix` whose package or check this repo
then uses (precedents: `flake-module-graph` in `modules/dev-shell.nix`,
`polymorph` in `modules/checks.nix`). Not for a nixpkgs package (skill
`new-package`) or a module file (`new-flake-module`).

## Steps

1. **Check the source.** CI must be able to fetch the repo (public, or a token
   the workflow has). Read its `flake.nix` for what it exports and which of its
   own inputs it takes.
2. **Add the input** with a comment saying what it is for, and that it runs
   only at build time if that is so. Give it `inputs.nixpkgs.follows =
   "nixpkgs"` when it has a nixpkgs input, so only one nixpkgs is evaluated.
3. **Run `git add` before any `nix` command** (AGENTS.md): flakes ignore
   untracked files.
4. **Lock only that input**, from `flake/`: `nix flake update <name>`. The old
   `--update-input` spelling is deprecated. Read the lock diff for the new rev
   and confirm nothing else moved.
5. **Consume it** in a `perSystem` as `inputs'.<name>.packages.default`. This
   flake lives in `flake/`, so the repository root (where `.agents/` and the
   book are) is `self.sourceInfo.outPath`, not `self.outPath`.
6. **Give a derivation check its own recipe.** `just check` is `nix flake
   check --all-systems --no-build`: it evaluates the derivation and builds
   nothing, so the check can pass without ever running. Add a recipe that
   builds it (precedent: `just polymorph-check`) and add the recipe to
   `preflight`. CI runs `just preflight`, so that edit gates PRs.
7. **Show the check can fail.** Break the thing it guards, build, and expect a
   non-zero exit and the finding in the log; then restore it. Read the real
   exit status, not a piped one (§20).
8. **State in the PR what the input is allowed to do**: build-time only, never
   in a hook, and whether upstream is unvetted.
9. **Update the docs** in the same change: the book chapter or rule that
   describes the thing. The book linter rejects dates in prose; cite the
   evidence instead.

## Bumping later

Run `nix flake update <name>`, read the lock diff, rerun the recipe from step
6, and state in the PR what the new upstream commits change for this repo.
Make it its own small change unless a feature needs it.
