# Claude Code cloud sessions: plan and runbook

_Last modified: 2026-10-31_

What to set up so a repo works well when the agent runs in a Claude Code
cloud session (claude.ai/code, or the app driving a remote container)
instead of on a host. A cloud session clones the repos fresh into an
ephemeral container, reaches GitHub through a git proxy and the GitHub MCP
tools, and has none of a host's tools beyond what the environment's setup
script installs. This page is the plan for bringing every repo up to that,
and the runbook for doing it to one repo. It applies to this repo and to
the repos extracted from it (factcheck, polymorph), and to any new one.

Each item names what a session hit without it. Everything under "Observed"
was seen in one session on 2026-10-31 that worked across factcheck,
polymorph and this repo; the tracking issue is
[#617](https://github.com/NireBryce/nixos-configs/issues/617).

## Contents

- [Quick facts](#quick-facts)
- [Plan](#plan)
- [Runbook: one repo](#runbook-one-repo)
- [Working in a cloud session](#working-in-a-cloud-session)
- [Observed](#observed)
- [See also](#see-also)

## Quick facts

| thing | in a cloud session | so |
|---|---|---|
| remote branch delete (`git push origin --delete`) | the git proxy answers HTTP 403; the GitHub MCP tools have no delete-branch call | turn on GitHub's auto-delete of head branches |
| `just` | not installed | setup script: `pip install rust-just` |
| `nix` | present, cannot fetch flake inputs (AGENTS.md, "Commands") | `nix eval`/`build`/`flake check` rungs are CI's; the git hooks degrade to `offline_checks.py` |
| `gh` | installed, not logged in | recipes built on `gh` don't run; the agent uses the GitHub MCP tools |
| repo `.claude/settings.json` (hooks, `attribution.commit`) | likely not loaded when the session starts above the repos | CI trailer check is the layer that holds; setup script wires `core.hooksPath` |
| repo skills | loaded, scoped by repo (`nixos-configs:ship`) | nothing to do |
| the session's branch | one name for the whole session, already checked out in the shared checkout | detach before `git worktree add`; restart the branch from the default after a merge |

## Plan

Status as of 2026-10-31. A row is done when its runbook step is applied
and [4. Check it](#4-check-it) passes for that repo.

| step | nixos-configs | factcheck | polymorph |
|---|---|---|---|
| 1. auto-delete head branches | on | **to do** | **to do** |
| 1. Claude GitHub App installed | yes | yes | yes |
| 2. setup script (`just`, hooks path) | **to do** (one per environment, covers all three) | | |
| 3. `.agents/settings.json` with `attribution.commit` | yes | yes | **to do** |
| 3. SessionStart hook | yes | yes | **to do** |
| 3. `.githooks/commit-msg` | yes | yes | **to do** |
| 3. CI trailer check over a PR's commits | yes (`check.yml`) | yes (`ci.yml`) | **to do** |
| 3. `.claude/` a real directory of symlinks | yes | yes | yes |

Order: step 1 and step 2 first (settings only, no PR, and they fix every
session at once), then polymorph's step 3 as one PR there, copied from
factcheck's files. A new repo starts from the runbook.

## Runbook: one repo

### 1. GitHub settings

In the repo on GitHub, **Settings → General → Pull Requests**, tick
**Automatically delete head branches**. GitHub then deletes the head
branch on merge, whoever merges, and each repo's `ship` skill already
treats an already-deleted remote branch as done. Delete any merged
branches left from before by hand, from their PR pages.

Install the Claude GitHub App on the repo
(https://github.com/apps/claude/installations/select_target). A session
reaches only the repos attached to it, at start or through `add_repo`,
and that needs the app.

### 2. Environment setup script

The cloud environment menu in the session's title bar → **Edit** →
**Setup script**. It runs when each new session starts, in the directory
above the repos, and cannot read the environment's saved secrets.

```sh
pip install rust-just
for r in */; do
  [ -d "$r.githooks" ] && git -C "$r" config core.hooksPath .githooks
done
```

The first line was run in a session: it installed `just` 1.59.0, and
listing polymorph's recipes with it worked. The loop has not been run as a setup script
yet; check it with [4. Check it](#4-check-it) in the next session.

### 3. Agent-tooling files

Copy from factcheck, which carries the smallest complete set, and adjust
names. In polymorph's case, one PR there:

- `.agents/settings.json` with `"attribution": {"commit": "Co-Authored-By: Claude"}`
  and a `SessionStart` hook entry; `.claude/settings.json` a symlink to it.
  `.claude/` stays a real directory: a symlinked `.claude` makes Claude
  Code refuse to create subagent worktrees.
- `.agents/hooks/session-start.sh`: prints branch, worktree and dirty
  state, and sets `core.hooksPath` when unset.
- `.githooks/commit-msg`: rewrites a Claude trailer that carries a model
  name or an email to `Co-Authored-By: Claude`.
- `scripts/check_trailers.py` (with its test) and a CI job running it over
  `HEAD^1..HEAD^2` on pull requests.

The CI job is the one layer that holds when a cloud session doesn't load
the repo's settings and hasn't wired the hook: the harness's own
attribution asks for `Co-Authored-By: Claude <model> <email>`.

### 4. Check it

In a new cloud session with the repo attached:

```sh
which just && just --list            # the setup script ran
git -C <repo> config core.hooksPath  # .githooks
```

Then land one small PR from the session: its CI trailer job passes, and
after the merge `git ls-remote --heads origin <branch>` prints nothing.

## Working in a cloud session

- **Worktrees.** The session's branch is checked out in the shared
  checkout, so `git worktree add <path> <branch>` refuses it. Detach the
  shared checkout first (`git switch --detach`), then add the worktree on
  the branch.
- **One branch name per session.** All the session's work goes to the one
  branch it was given. After that branch's PR merges, restart it from the
  default branch for the next change (`git worktree add -B <branch> <path>
  origin/<default>`, then `git push --force-with-lease`). With auto-delete
  on, the old remote branch is already gone.
- **Merging.** Through the GitHub MCP merge tool, pinned with
  `expectedHeadSha` to the head CI passed on. It takes the full 40-character
  SHA; a short one is rejected.
- **CI.** Subscribing the session to a PR's activity delivers CI results
  and review comments as events; nothing needs polling.
- **Attribution.** Copy no trailer from an earlier commit: a
  `Claude-Session:` line copied that way names the wrong session.

## Observed

- The git proxy refused `git push origin --delete` and `git push origin
  :refs/heads/<branch>` with HTTP 403, while pushes, PR creation and
  merges went through.
- `core.hooksPath` was unset in this repo's fresh clone, and no repo's
  session-start output reached the session's context; the session's
  working directory was the directory above the repos. That a repo's
  `.claude/settings.json` is not loaded then is the likely cause, not
  confirmed.
- `gh auth status` reported "Failed to log in to github.com using token".

## See also

- [#617](https://github.com/NireBryce/nixos-configs/issues/617), the
  tracking issue.
- Skills `ship`, `use-a-worktree`, `agent-scripts`.
