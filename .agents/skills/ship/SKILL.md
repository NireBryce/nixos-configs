---
name: ship
description: Lands work on experimental through a branch, a PR, a confirmed merge and delete, the merge, and deleting the branch.
when_to_use: A bare push, ship it, land this or merge this, or any ask to get changes onto experimental. Never push directly to main.
---

# Landing work on experimental in nixos-configs

**Needs:** bash-guards

## Applies to

Use this skill only when the ask is to get changes onto `experimental`: a bare "push", "ship it", "land this", "merge this". It was established 2026-08-21 after a session read a bare "push" as license for a direct push to `main`, and has targeted `experimental` since 2026-08-25.

It does not apply to other git work:

| ask | what to do |
|---|---|
| "push this branch" | `git push` it. No PR, no gates. |
| "open a PR" (no merge ask) | Open it and stop. Steps 2-3 are not yours to run. |
| "commit this" | Commit. Pushing was not asked for. |
| "promote to main" | Promotion flow, [side-flows.md](side-flows.md). Do not push directly; `main` has its own ruleset. |
| any other branch named outright | Push directly there, [side-flows.md](side-flows.md). |
| fork, non-`origin` remote | Ordinary push. |

If you are unsure whether an ask means `experimental`, ask. Assuming it does not is the mistake this skill exists to prevent.

`experimental` has been the default branch since 2026-09-03 (trunk + promotion; ruleset details in [side-flows.md](side-flows.md)). `gh pr create` targets it by default; `--base experimental` is redundant but harmless. `main` moves only via a PR from `experimental`.

Ask one confirmation up front that covers both actions: "merge, and delete the branch afterward?" On yes, do both in the same turn. Do not use `--delete-branch`: it removes only the remote branch, and the flow also needs the local branch gone and `experimental` checked out and pulled. (This was two asks until 2026-09-05.)

## 0. Fetch, then is it green?

Run `git fetch origin` first. Other sessions land PRs concurrently, and a branch cut from a stale `experimental` makes step-2 comparisons meaningless. `just agent where` fetches, then prints (read-only) the branch line, dirty paths, commits, the diff stat against `origin/experimental`, and this branch's PR.

Before opening a PR, run the preflight (CI, `.github/workflows/check.yml`, runs the same `just preflight` minutes later and is only a backstop):

```sh
just agent preflight-brief   # all of preflight, steps concurrent, one line each; `just preflight` for full output
```

Its `just check` forces every host's toplevel and home, darwin included (`flake/modules/checks.nix`, since 2026-09-29), so there is no host to pick. If a drvPath moved, find out what changed with `just diff HEAD`; a permuted `systemPackages` order is not a value change.

**Docs-only diff.** If every changed path is under `wiki/`, `.agents/skills/` or `.agents/rules/`, or is `AGENTS.md`, run `just wiki-lint` instead. The other preflight steps evaluate Nix and run script tests against fixtures, and none read these files. Add `just agent book-lint check` if `book/` changed. CI still runs the full preflight on the PR. Report the rung as "doc lint passes". Run the full preflight for any `.nix`, script, hook or `.justfile` change, even a comment-only one (a `${...}` in a Nix `''` string comment interpolates), and for renaming or deleting a skill or rule file, which `lessons-map.toml` cites by path.

**Multi-commit change.** Check that each commit is green (`agent-lessons-learned.md` §15):

```sh
just agent preflight-each [--jobs N] [<range>]   # default origin/experimental..HEAD
```

This runs `preflight-brief` on every commit, oldest first, in a throwaway detached worktree. The worktree is removed on any exit, including Ctrl-C; one left by a SIGKILLed run is swept by the next run, which touches only worktrees it marked itself. It prints one `ok`/`FAIL` line per commit, in commit order, so it suits a background runner, and exits non-zero if any commit failed. A passing `just check` is reused for later commits with the same `flake/` tree (printed as `cached`); a failed one reruns. For a larger range, add `--jobs N` if memory permits: up to N commits run at once, each in its own worktree. N is cut to what available memory covers (`MemAvailable`, or a tighter cgroup limit; about 5 GiB per concurrent check, about 1.5 per job; 1 if it cannot tell), and the script prints when it cuts.

## 1. Branch, push, open the PR

Never commit onto `experimental`. Run `git status -sb` first:

- **Dirty tree on `experimental`**: run `git checkout -b <branch>` and commit there.
- **Unpushed commits on local `experimental`** (`[ahead N]`):
  ```sh
  git branch <branch>              # keep the commits
  git status --short               # anything NOT part of those commits?
  git reset --hard origin/experimental
  git checkout <branch>
  ```
  Read that `git status --short` before the reset. `git branch` preserves only the commit; `reset --hard` destroys any other dirty state (someone else's uncommitted edit) with no recovery. If anything exists beyond your commits, stop and ask. The git-guard hook denies `reset --hard` on a dirty tree (since 2026-09-29; its earlier `ask` was a no-op under `--permission-mode auto`, issue #182), in Claude Code and in ZCode (both harnesses wire the same guard). It falls back to `ask`, still a no-op under auto mode, when it cannot tell which repo the reset acts on: anything beyond plain `cd <path>` and `git [-C <path>] <subcommand> <args>` joined by `&&`/`;`. So the `git status --short` read stays your job. To discard edits of your own that are already in the branch (moved from the shared checkout, say) after the user has approved, use `git stash push` then `git stash drop` (skill `use-a-worktree`); the guard denies `checkout --` and `restore`.

Commit with `just agent commit` (`.agents/scripts/ship.py`, whose header lists the incident behind each rule):

```sh
just agent commit [--agent <you>] -- <paths...> <<'EOF'
feat: ...
EOF
```

The script requires a pathspec (a bare commit or `--amend` takes whatever is staged now). It reads the message on stdin (a quoted heredoc, so backticks and `$(...)` are not executed), refuses `experimental` and `main`, and appends `Co-Authored-By: <agent>` (default `Claude`; name only, no model, no email) unless the message already has one. If you committed the wrong paths, run `git reset --soft HEAD~1`, check `git status --short`, and recommit. `--amend` is not wrapped: use `git commit --amend -F - -- <paths...> <<'EOF'`.

- Give the branch name and the first commit line a `feat/`, `fix/` or `docs:` prefix (first line only; the body stays what/why/verified narrative).
- Keep each commit green (§15). One coherent commit beats two artificial ones.
- Describe only what the commit contains, never a note or fix still to come.

Then run `just agent recurring export`. It writes one line: this host's command shapes to the private command log (skill `agent-scripts`). Report "not set up" or a failure; neither is a reason to stop. Write the PR body to a file, then run:

```sh
just agent pr <body-file> [--title T]   # --edit <n> replaces an open PR's body
```

The script pushes with `-u` when the branch has no `origin/<branch>` upstream (a branch cut from `origin/experimental` tracks the trunk, so a bare push fails), then runs `gh pr create --base experimental --body-file`. The title defaults to the only commit's subject; several commits need `--title`. It refuses on `experimental`/`main`, and refuses a body missing the disclosure line at top or bottom (below). The body goes in a file because backticks in an inline `--body` are executed, as in a commit message.

The PR body covers what changed, why, what was verified, and what was left alone, under `.github/PULL_REQUEST_TEMPLATE.md`'s headings. For a security-relevant change, the PR body and commit messages state what is now enforced, never what got past the old version or what it could reach; that goes to `elly/infra-notes` (AGENTS.md, Working in this repo).

Put the LLM-disclosure line at both the top (before "What changed") and the bottom, because a harness footer lands at the bottom regardless. Use the model-agnostic `🤖 Generated by an LLM agent` (`propose-issue`'s reasoning: an agent cannot verify its model or harness). A harness-injected footer is accurate by construction, so there is no reason to name it at the top.

## 2. Preview, then ask

Read back what landed instead of recalling it. `just agent where <n>` is the quick look: state and `mergeStateStatus` without waiting for CI. The gate is `ship-ready`:

```sh
just agent ship-ready <n>
```

It waits for CI (`gh pr checks --watch`; this takes minutes and is required), then checks that:

- the PR is open and not a draft
- `mergeStateStatus` is `CLEAN` (`mergeable` only means no conflicts: #413)
- the base is `experimental`
- the head is in this repo and is neither a protected branch nor the base (`land` deletes the head by name; §52)

It prints the title, URL, stats, the commit list, and the merge method: one commit uses `--rebase`, more use `--merge` (their messages carry real reasoning, and squashing flattens it).

**NOT READY** means do not ask; fix what it names. For a red check, run `gh run view <run> --log-failed`, fix, push, and re-run. If `just preflight` passed locally, the step it missed belongs in `preflight` too.

**READY**: show that summary and ask the one combined question.

**No**: leave the PR open, say so, and stop. Do not merge, close, delete, or clean up.

## 3. Merge, then delete — on yes only

```sh
just agent ship-land <n>
```

The script:

1. re-runs the gate and refuses if it fails
2. merges with the computed method (never `--delete-branch`, pinned to the head commit the gate read) and confirms `MERGED`
3. checks out and pulls `experimental` (from a linked worktree whose shared checkout holds `experimental`, it leaves that checkout alone and detaches this worktree instead)
4. deletes the local branch, and the remote branch if still there
5. runs `just close-fixed <n>` (#177: closing keywords silently not closing)

Any failure stops it and prints what is left; a failed merge deletes nothing. Raise the failure instead of retrying silently. A remote-branch delete that errors with "remote ref does not exist" or "cannot lock ref" is already done (the repo deletes merged branches itself); the script prints `failed, but its goal already holds; going on`.

**Merged outside this flow** (web UI, another session): the branch stays. `just branches` classifies local branches by patch-id, which catches rebased merges; `git branch --merged` does not, because rebasing gives new SHAs (11 stale branches accumulated by 2026-09-11, hiding 3 unmerged). `just branches prune` deletes only landed branches and asks first. Agent sessions have no terminal for the prompt, so pass `--yes`; without it, prune prints the verdict, deletes nothing and exits 2. Check it at session start, like `git worktree list`.

Report the merge commit and the branch's fate, including anything `ship-land` left for you. Never report a commit range as if pushed to `experimental`. After a land that ran outside `ship-land`, still run `just close-fixed <n>`: it re-checks every issue the PR claims to fix and closes the ones still OPEN, with a comment saying it was a hand close.

## Other flows

Promotion to `main`, branch rulesets, one-tree-two-PRs traps, named-branch exception: [side-flows.md](side-flows.md).

A merge conflict in `.claude/settings.local.json` is the user's local allowlist, not shipped config. Take the simplest resolution and move on (§42).
