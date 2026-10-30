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
`new-package`) and not for a module file (`new-flake-module`).

## Steps

1. **Check the source first.** The repo must be fetchable by CI (public, or a
   token the workflow has). Read its `flake.nix` for what it exports and which
   of its own inputs it takes.
2. **Add the input** with a comment saying what it is for and that it runs only
   at build time if so. Give it `inputs.nixpkgs.follows = "nixpkgs"` when it has
   a nixpkgs input, so one nixpkgs is evaluated.
3. **`git add` before any `nix` command** (AGENTS.md): flakes ignore untracked
   files.
4. **Lock only that input**, from `flake/`: `nix flake update <name>`. The old
   `--update-input` spelling is deprecated. Read the lock diff: the new rev,
   and that nothing else moved.
5. **Consume it** in a `perSystem` as `inputs'.<name>.packages.default`. This
   flake lives in `flake/`, so the repository root, where `.agents/` and the
   book are, is `self.sourceInfo.outPath`, not `self.outPath`.
6. **A check that is a derivation does not run under `just check`.** `just
   check` is `nix flake check --all-systems --no-build`: it evaluates the
   derivation and builds nothing, so the check can be green without ever
   running. Give it its own recipe that builds it (precedent: `just
   polymorph-check`) and add the recipe to `preflight`. CI runs `just
   preflight`, so that one edit gates PRs.
7. **Show the check can fail.** Break the thing it guards, build, expect a
   non-zero exit and the finding in the log, then restore it. Read the real exit
   status, not a piped one (§20).
8. **Say what the input is allowed to do** in the PR: build-time only, never in
   a hook, unvetted upstream if so.
9. **Docs:** the book chapter or rule that describes the thing, in the same
   change. The book linter rejects dates in prose; cite the evidence instead.

## Bumping later

`nix flake update <name>`, read the lock diff, rerun the recipe from step 6,
and say in the PR what the new upstream commits changed for this repo. Do it as
its own small change unless a feature needs it.
