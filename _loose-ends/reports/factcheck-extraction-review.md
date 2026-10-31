# Report: factcheck extraction and adoption (for review)

_Status: working doc, written 2026-10-30 by an agent session. The
extraction and the switch-over described here are live on `experimental`
(PR #601); the review it asks for, and the follow-up work, are only
partly done, so this is committed as a record of where things stand
rather than left untracked. Trim it once review is finished._

## What happened, in one paragraph

`wiki/meta/scripts/check_docs.py` (2,079 lines, the doc-vs-repo checker
behind `just wiki-lint`) was extracted into a standalone tool,
[factcheck](https://github.com/NireBryce/factcheck) (public, stdlib-only
Python 3.11+, no dependencies), and nixos-configs was switched over to
it: PR #601 (branch `feat/factcheck-flip`, merge commit `ecb4ca37` on
`experimental`, CI green). Everything fleet-specific stayed in this repo
as factcheck plugins under `tools/docchecks/`, wired by
`factcheck.toml` at the root. The tool is documented as **experimental**
in its README, the book's checks chapter, AGENTS.md, and the wrapper
header, each naming the revert.

## Where everything lives now

- **Upstream tool**: github:NireBryce/factcheck — engine (registry,
  findings, config, plugins loader, CLI), markdown core (fences,
  headings, GitHub slugs), and the general checks (links, anchors,
  contents + fixer, dates, siblings, recipes, skills, skill-files,
  docrefs, counts mechanism, rules, summaries, generated-region engine).
  Pinned in `flake/flake.lock`; consumed via the dev shell
  (`flake/modules/dev-shell.nix` puts its CLI on PATH and exports
  `FACTCHECK_SRC`).
- **This repo's plugins**: `tools/docchecks/{tree,roster,imports_table,
  secrets,routes,lessons,nixos_regions}.py`. `tree.py` wraps
  `wiki/meta/scripts/nixtree.py` (kept — `wiki_gen.py` still imports it),
  so there is one static tree reader shared by checks, regions, and
  `just modules`.
- **Wiring**: `factcheck.toml` (scopes, bindings, plugin list);
  `flake/scripts/factcheck.sh` (find-the-tool ladder: PATH →
  `$FACTCHECK_SRC` → `nix develop` → exit 75) and
  `flake/scripts/factcheck-test.sh`; `.justfile` (`wiki-lint`,
  `factcheck-test`); `offline_checks.py`; the edit hook's siblings
  check; `modules.py`'s static reading; the mirror/anchor sets in
  `test_preflight_mirror.py`, `test_offline_checks.py`,
  `test_guards.py`.
- **Deleted**: `check_docs.py`, `test_check_docs.py`. Kept:
  `wikicore.py` and `nixtree.py` (wiki_gen imports them),
  `wiki_gen.py` (still the regions' writer, `just wiki-gen`),
  `mdfence.py`, and the independent reporting scripts.

## Verification already done (so the reviewer doesn't redo it blindly)

- **Parity**: on a full-tree copy of this repo, factcheck and
  check_docs.py produced identical finding sets untouched (41/41) and
  with defects injected (49/49) across every check; the generated
  regions render byte-identically (the plugins carry wiki_gen's marker
  strings). The one documented exception is the lessons-map half's
  *comparison method*, not its behavior — this repo's plugin calls the
  same `lessons_map.validate` the old check called.
- **Live**: both tools report no findings on the checkout;
  `just preflight` passed on the branch (32 steps) and CI ran green on
  the final commit; `just check`/`just modules`/`just lint` included;
  nire-durandal's toplevel drvPath is identical on both sides (no host
  module changed).
- **Runs stated plainly**: everything above is the preflight/evaluates
  rung plus offline parity work. No host switch (none was needed). The
  edit hook's siblings reminder gets its first real workout on the next
  wiki edit.

## Known divergences and gaps (the reviewer should start here)

1. **Offline coverage regression, accepted for now**: the pre-commit/
   pre-push wiki lint needs factcheck on PATH; a nix-less environment
   cannot fetch the flake input, so that step skips there (printed, CI
   runs it). The edit hook degrades the same way (exit 75 → silence).
   A non-nix machine *with* network is told to `pipx install` the tool
   (it is pip-installable upstream). The fully-offline fix would be a
   verified vendored mirror (committed snapshot + a preflight diff
   against the locked input) — deliberately not built yet.
2. **Plugin fixture tests**: `tools/docchecks/` has no in-repo fixture
   suite. Coverage = upstream's 147 tests, a pre-merge parity run with
   injected defects, and live exercise every preflight. A follow-up
   vendoring plugin fixtures under `tools/docchecks/tests/` would close
   the §1 letter.
3. **One micro-divergence**: the old file's `MD_LINK` was defined twice
   and silently shadowed, so skill-file links ran with the wider links
   pattern at runtime; the port gives each check its own regex, so a
   skill-file link whose target contains a space would be skipped where
   the old runtime checked it. No such link exists; align upstream if
   runtime parity is preferred over source intent.
4. **Intended divergences**: message wording (see-advice no longer
   names repo-only skills; fix hints say `factcheck fix-contents`); a
   missing `.justfile` is vacuous instead of a traceback; an unexpected
   positional argument is refused (the ancestor silently dropped it —
   dropping a root once produced a wrong-repo green, fixed upstream at
   `92491dd` with a regression test).
5. **Lock drift**: upstream `main` has moved past the locked rev (docs
   and pip packaging, no check-behavior changes). Update the lock at
   leisure.

## How to review this

- Run it: `just wiki-lint`; `nix develop ./flake -c factcheck checks`;
  break something small on a scratch copy (e.g. rename a recipe in a
  wiki page, stale a sibling's date) and confirm both the finding and
  the exit code.
- Compare against the ancestor: `git show e8211c06:wiki/meta/scripts/
  check_docs.py` is the pre-extraction script (full 2,079-line source
  with its per-check design docstring); the parity method above is
  reproducible with `git worktree add` at that commit.
- The upstream suite: `just factcheck-test` (147 tests, needs
  `FACTCHECK_SRC` — set by the dev shell).
- Read for: the plugin ports vs the ancestor source (especially
  `imports_table.py`'s exclusion-cue heuristic and `docrefs`' bare-count
  opt-outs — the narrowing stories are in their docstrings); the
  wrapper's failure modes (exit 75 paths, silent-degradation risk in
  the hook); and whether the experimental-status notes are still true
  (they expire into "has a track record" after a few real merges).
- Revert, if review says so: `git revert ecb4ca37` restores
  check_docs.py wholesale (the plugins and config are additive and
  harmless left behind), or pin the `factcheck` input to an earlier rev
  for a narrower rollback.
