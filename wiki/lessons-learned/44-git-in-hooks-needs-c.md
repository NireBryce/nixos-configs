# 44. A hook that runs `git` from a non-toplevel cwd needs `-C`, not a cleared GIT_DIR — the docs' own suggested fix broke the index lock instead

_Last modified: 2026-09-09_

§44 of [lessons-learned.md](../lessons-learned.md#44-a-hook-that-runs-git-from-a-non-toplevel-cwd-needs--c-not-a-cleared-git_dir--the-docs-own-suggested-fix-broke-the-index-lock-instead) — that page keeps the one-line version of every lesson; this is §44's full account.

2026-09-02, landing an unrelated docs commit from a worktree
(`docs/claude-cave-to-wiki`, PR #149). `.githooks/pre-commit` re-stages
`flake/scripts/lint-baseline.json` with `git add
"${repo_root}/flake/scripts/lint-baseline.json"` — an absolute path,
computed from `repo_root="$(git rev-parse --show-toplevel)"` at the top of
the hook. It had run this way in every prior session without incident. This
time the commit came back with a second, stray copy of the file at
`scripts/lint-baseline.json` — no `flake/` prefix, same content, not staged
by anything I'd run. Re-running the hook script *by hand* from the same
worktree never reproduced it; only a real `git commit` did.

The tool reporting success — `git add`'s own exit code, `set -euo
pipefail` not tripping anywhere — proved nothing (§1's shape exactly).
Traced it by patching a throwaway copy of the hook to print `git status
--short` and `git ls-files -s` immediately after the `git add` line, then
triggering it with a real commit rather than a manual invocation, since that
distinction was itself the reproduction condition. The index right after
`git add` already had two entries with the *identical blob hash* — one at
`flake/scripts/lint-baseline.json` (correct), one at
`scripts/lint-baseline.json` (staged as added, missing from the working
tree — `AD` in `--short`). Minimal repro, no hook involved at all: `cd
<worktree>/flake && GIT_DIR=<worktree's-own-gitdir> git add
<worktree>/flake/scripts/lint-baseline.json` stages it at
`scripts/lint-baseline.json`.

The mechanism, confirmed against `githooks(5)` rather than guessed: Git
exports `GIT_DIR` (and `GIT_WORK_TREE`, `GIT_INDEX_FILE`, etc.) into a
hook's environment so a `git` command the hook runs can find "the
repository" without re-discovering it — but in a linked worktree that
export is `GIT_DIR` alone, no matching `GIT_WORK_TREE`. Once `GIT_DIR` is
set explicitly, `git` stops walking up from cwd to find the work-tree root
and falls back to treating cwd itself as that root. The hook's own `cd
"${repo_root}/flake"` (so `lint.py` runs the same way `just lint` runs it)
put the inherited-`GIT_DIR`, no-`GIT_WORK_TREE` `git add` in exactly that
situation: it silently re-derived "flake/" as the top, and the absolute
path it was given got reinterpreted relative to that — the leading
`flake/` stripped, not preserved. No error at any layer; the given path
existed, the blob was real, the add "succeeded."

`githooks(5)`, "Environment Variables and Foreign Repository Access", says
this exact thing and gives a fix: "if your hook needs to invoke Git
commands in a foreign repository or in a different working tree of the
same repository, then it should clear these environment variables so they
do not interfere" — `unset $(git rev-parse --local-env-vars)`, run once at
the top of the hook before anything else touches `git`.

Applied that literally first, and it made things *worse*, not better: the
next real `git commit` failed outright with `fatal: Unable to create
'.../index.lock': File exists`, reproducibly, every single retry. The
docs' own suggested one-liner clears every "local" env var as a set,
`GIT_INDEX_FILE` included — and `GIT_INDEX_FILE` isn't part of this bug at
all; it's how the outer `git commit` process tells the hook's own `git
add` which *already-open* index file to write into. Unset it, and that
`git add` re-derives a index path via ordinary discovery instead — which
still *resolves* to the same file, but no longer as "the same open
session," so it collides with the outer commit process's own lock on it.
Applying a real fix without testing it against a real `git commit` — not
just re-reasoning that the docs' own example must be safe — would have
shipped a second, worse bug in the same commit as fixing the first one.

The fix that actually holds up under a real `git commit`, retried several
times: don't touch the environment at all. `git -C "$repo_root" add
flake/scripts/lint-baseline.json` — an explicit `-C` plus a path relative
to it, instead of a `cd` plus an absolute one — sidesteps the whole
GIT_DIR-vs-cwd question directly rather than reasoning about which env
vars are and aren't safe to clear. `GIT_INDEX_FILE` stays exactly as git
set it. Confirmed clean over several real `git commit`s in the same
worktree, not just the manual hook invocation that never reproduced the
original bug either.

A plain, non-worktree checkout never hit any of this — `git rev-parse
--show-toplevel` there has no `GIT_DIR` override to contend with,
cwd-walking finds the real top on its own — which is exactly why it went
unnoticed through every prior session that installed the hook and
committed from the main checkout.
