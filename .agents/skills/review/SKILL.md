---
name: review
description: Reviews a change using this repo's own checks and known traps.
when_to_use: Reviewing a PR, branch or commit, or before saying your own change is done.
---

# Reviewing a change in nixos-configs

**Needs:** bash-guards

## Applies to

Use this skill when asked to review a PR, branch, or commit (yours or
another's), or when you are about to say "done" on your own change and want
the reviewer's gate. It supplements a generic code-review pass with failure
modes this repo's history already hit (issue #223, 2026-09-09). It is not for
writing a module; the trap skills below own that, and this file is their
review-side summary.

## Run first — the mechanical checks

Reading the diff is not enough, because bugs serialize. Run these in order:

1. `just modules` checks for untracked files and for drift between wiki-lint's
   file-only reading and the evaluated graph. A module no host reaches
   (orphan) fails `just check` (`checkOrphans = "eval"`, so `--no-build` fails
   too). A repeated module or category name, or an unknown `includes` name,
   fails evaluation itself (dirs-as-categories,
   `wiki/config-structure/module-files.md`).
2. `git status --short`. **`git add` before `nix eval`**: an untracked new
   file does not exist to the flake, so a passing eval may never have seen it.
3. `just agent preflight-brief` runs wiki-lint, check, modules, lint
   (statix/deadnix ratchet) and the script fixture tests, one line per step.
   These are the steps CI runs (`just preflight` prints everything). For a
   docs-only diff, `just wiki-lint` is enough (skill `ship`, step 0). Its
   `just check` forces every host's toplevel and home, darwin included (since
   2026-09-29). No host is skipped because a cheap attribute proves nothing:
   `networking.hostName` resolved while four things were broken.
4. `just agent lessons` lists every `.agents/lessons-map.toml` topic the
   diff's files fall under, with the lessons behind each. Read the diff for
   those traps in addition to the list below.
5. If the drvPath moved, run `just diff <ref>`. A permuted
   `environment.systemPackages` is not a value change, and a same-looking hash
   can hide dead code. Known gap #242: `diff` fails on cube because the
   fingerprint assumes impermanence's `/persist`; fall back to `nix eval
   --json` of the specific options on both sides.

## Read for — traps a diff can't show

- **Filed in the right directory?** Category = directory. A module outside
  every category tree is collected by nothing, with no error
  (`new-flake-module`). A first subfolder of modules can turn a plain folder
  into a category.
- **Module file shape?** The first line is the dirs-as-categories comment, the
  keys are only classes, `includes`, `enables` and `folderIsCategory`, and the
  header takes only the `lib`/`inputs` it uses.
- **Two files writing the "same" file?** `home.file.<n>.text` and
  `home.sessionPath` **concatenate** across modules, which silently doubles
  content. Reading a generated dotfile back gives false negatives; eval the
  attribute (`home-manager-dotfiles`).
- **`${...}` inside a `''` string?** If it is meant as shell text or a
  comment, it must be `''${...}`. Otherwise Nix interpolates it, usually as an
  eval error (sometimes silently).
- **`flake.modules` inside `perSystem`?** There is no `<system>` axis, so it
  cannot work.
- **Touches impermanence, initrd, `fileSystems`, or boot?** Read
  `impermanence-initrd` first (shell mount views mislead; use
  `/proc/1/mountinfo` and `/dev/disk/by-uuid/`). Check `hosts.nix` for which
  hosts wipe `/root`; not all do.
- **Platform gating?** Support is derived from `meta.platforms`; a
  hand-written `lib.mkIf (!pkgs.stdenv.isDarwin)` is a finding. Homebrew
  overlap is never automatic: run `just available --duplicates`
  (`package-platform-support`).
- **Existing `programs.*` integration missed?** Flag hand-rolled dotfiles.
- **Anything that can print a secret?** Bare `sops -d`, `journalctl` or `ps`
  near a unit with a secret on its command line, or a credential outside
  `secrets.yaml` (`secrets-hygiene`). For a flagged hit, run
  `triage-flagged-secrets` before any rotation talk.

## Flake input bumps

A lock move is the change most likely to pass CI and still be wrong. Check:

- **The locked rev is the tag the title names.** Compare
  `gh api repos/<owner>/<repo>/git/ref/tags/<tag> --jq .object.sha` against
  `flake.lock`'s `rev`, and confirm only the intended input moved (`git diff
  flake/flake.lock`).
- **The upstream changelog's Breaks section, read in full.** Do not infer
  breakage from the one option that visibly broke. Re-check every option the
  repo sets on that input.
- **Every prose claim about upstream behaviour** (a field exists, a mode fails
  under `--no-build`) names where it was read (changelog, source) or says it
  is unverified. "Looked it up" is not a source.
- **A link dropped from the docs** (an upstream issue) is dropped only because
  the issue is closed. Check with `gh issue view`, not memory.

## Conventions worth flagging

- **Line width of added prose.** `just comment-wrap` holds comments to 80
  columns, but no checker covers skill or book prose. Scan the diff for added
  lines far past their neighbours (`git diff -U0 | grep '^+' | awk
  'length>81'`) and re-flow them.
- **Trailer** on agent commits: `Co-Authored-By: <agent>`, name only, no
  model or email. The Conventional-Commits prefix goes on the first line only.
- **A bug recorded in a comment stays in the file.** Deleting a "why" comment
  needs a reason; a stranded one moves to a `history` heading. Exception: a
  security weakness. Its shapes and impact go to `elly/infra-notes`, and the
  file says only what is enforced.
- **Public text about a security change** (commit message, PR body, code
  comment, test name or comment, wiki): flag any line saying which inputs got
  past the old version, what they could reach, or which host is exposed
  (AGENTS.md, Working in this repo). Test inputs themselves are fine.
- **Renamed-away name**: the declaration should say what it was.
- **Dated "as of" claims**: a date records when someone last checked, not
  proof (`fact-hygiene`). Present-tense claims about other files are live
  pointers; check whether they survive this change.
- **Wiki touched?** `wiki-sync` belongs in the same change.
- **Upstream filings** (nixpkgs, ble.sh, ...): never without the user saying
  so explicitly. Even filings here can ping upstream through `owner/repo#123`
  autolinking, so grep the draft.

## Saying the outcome

An undated "verified" means *evaluates*. State which rung you reached: in the
tree, or switched and checked live (`investigate-bug` step 4). Reporting "it
works" from an eval alone overclaims.

## See also

- Trap skills: `new-flake-module`, `home-manager-dotfiles`,
  `impermanence-initrd`, `package-platform-support`, `secrets-hygiene`.
- `ship`: the pre-PR gate; its step 0 is "Run first" from the author's side.
- `wiki/agent-lessons-learned.md`: every § records a past mistake.
