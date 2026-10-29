# Git and agent workflows

A change moves through a fixed loop. It gets its own worktree and commits with
a provenance trailer. Checks run at commit and push, then preflight, and the
`ship` [skill](glossary.md#skill) routes it to a merged PR. The sections below follow that order,
then cover what "push" means, where issues and PRs may be filed, how to report
what was verified, and how a session without nix is checked. A worked example
closes the chapter. The rules apply to human and agent contributors alike.

## One worktree per task

Work that will branch, commit or check out happens in its own
[worktree](glossary.md#worktree), outside the shared checkout. A worktree has
its own directory and `HEAD` and shares the repository's branches and
objects, so two sessions in one repo do not see each other's checkouts
mid-task. Read-only work (reading files, `just check` on what is checked out)
needs no worktree, and neither does work in the shared checkout when the repo
owner says to work there.

Create one with the helper, which fetches `origin` first and refuses an
existing branch or path:

```sh
just agent worktree new <branch> [<base>] --root <scratch-dir>
```

The base defaults to `origin/experimental`. The worktree lands at
`<scratch-dir>/wt-<branch>`, with any leading `feat/`-style component
dropped, and the command prints only that path. `$AGENT_SCRATCH` can stand in
for `--root`. Under Claude Code, a subagent gets its own worktree by passing
`isolation: "worktree"` to the Agent tool.

Clean up with `git worktree remove --force <path>` once the work has shipped
or been abandoned. `just agent worktree prune --root <dir>` reports each
linked worktree under `<dir>`. With `--yes`, it removes only clean worktrees
whose commits have landed, or that have no commits ahead, were never pushed,
and have sat untouched past `--min-age` (60 minutes by default). It never
removes a dirty worktree or the main checkout.

Check: `just agent where` (or `git status -sb`) inside the new directory shows
the new branch.

## Branch names

A branch name starts with a type prefix such as `feat/`, `fix/` or `docs/`.
The first line of a commit starts with the same type and a colon, as in
`docs: fix the command`. The commit body states what changed, why, and what
was verified.

## Commits and the provenance trailer

Commit with `just agent commit`, which names exactly the paths to commit and
adds the provenance trailer. The message comes on stdin through a quoted
heredoc, so backticks and `$(...)` are not executed:

```sh
just agent commit -- <paths...> <<'EOF'
docs: one-line summary

What changed, why, and what was verified.
EOF
```

The helper:

- refuses to commit without a pathspec, because a bare `git commit` takes
  whatever is staged at that moment;
- refuses to commit on `experimental` or `main`, since work lands there only
  through a PR;
- appends `Co-Authored-By: <agent>` (default `Claude`, or `--agent <name>`)
  unless the message already has one;
- warns when that trailer carries an email or a model name.

The trailer names the agent only. An agent cannot verify which model is
executing it, so the trailer records what it knows. Three layers hold the
convention:

1. `attribution.commit` in `.agents/settings.json` makes Claude Code ask for
   `Co-Authored-By: Claude`.
2. `.githooks/commit-msg` rewrites a Claude trailer that carries a model name
   or email into the canonical form.
3. `check_trailers.py` fails a PR in CI that still carries a non-canonical
   Claude trailer.

Another agent's trailer passes through all three, so it must be formed
correctly when the commit is written.

Check: `git log -1` shows the trailer as the last line of the message.

## `git add` before `nix eval`

A flake in a git repository ignores untracked files, so an unstaged new module
does not exist for Nix. Stage new files before any evaluation; the reasoning
is in
[Step 4 of adding a module](adding-a-module.md#step-4-git-add-before-nix-eval).
Two [guard hooks](glossary.md#guard-hook) remind you: the
[untracked-nix guard](agent-checks-and-guards.md#the-untracked-nix-guard)
warns when a `Bash` call evaluates the flake with untracked files, and the
[edit-check hook](agent-checks-and-guards.md#the-edit-check-hook) reminds you
after an edit that creates an untracked module file. `just modules` also
reports untracked `.nix` files.

## What runs at commit and push

Once `core.hooksPath` points at `.githooks`, each commit runs the
[lint ratchet](glossary.md#lint-ratchet) and the trailer rewrite, and each
push without nix runs the offline preflight steps. The [session-start hook](agent-checks-and-guards.md#the-session-start-hook) sets
`core.hooksPath` when it is unset; `just install-hooks` does it by hand. A
failing hook stops the commit or push. `--no-verify` bypasses the hooks, but
`AGENTS.md` says it should not be needed, and CI runs the same checks
regardless. What each hook does is in
[Checks, guards and hooks](agent-checks-and-guards.md#git-hooks).

## Preflight is the CI checklist

[Preflight](glossary.md#preflight) is the `just preflight` recipe, and CI runs
the recipe itself, never a copy of its steps. `just --show preflight` lists
the current steps. A step added to the recipe gates PRs with no edit to
`.github/workflows/check.yml`; `just preflight-mirror-test` fails if the
workflow stops calling the recipe or adds checks of its own beyond the
CI-only ones. On a pull request CI also runs `check_trailers.py` over the PR's
own commits.

`just agent preflight-brief` runs the same steps concurrently and prints one
line per step, with the tail of any failure. For a branch with several
commits, `just agent preflight-each [<range>]` runs it on each commit in a
throwaway detached worktree, because each commit must be green on its own.

## What "push" means

A bare "push", "ship it", "land this" or "merge this" means the `ship` skill,
landing on `experimental`, the default branch. `main` is the promoted
known-good branch and moves only by a PR from `experimental` after hardware
verification. Other asks map differently:

| The repo owner says | The contributor does |
|---|---|
| "push this branch" | `git push` it; no PR, no gates |
| "open a PR" | Opens it and stops |
| "commit this" | Commits; pushing was not asked for |
| "promote to main" | The promotion flow: a PR from `experimental` to `main`, merged with a merge commit |
| a branch named outright | Pushes directly there, except `main` |

When unsure whether an ask means `experimental`, ask.

## The ship flow

The `ship` skill lands work on `experimental` through a branch, a PR, one
combined question to the repo owner (merge, and delete the branch afterward?),
the merge and the branch deletion.

1. Check. `just agent where` fetches and prints the branch, dirty paths,
   commits and diff stat against `origin/experimental`. Then
   `just agent preflight-brief`.
2. Open the PR. Commit with `just agent commit`, write the PR body to a file,
   and run `just agent pr <body-file>`. It pushes the branch and runs
   `gh pr create --base experimental`. It refuses on `experimental` or `main`
   and refuses a body missing the [disclosure line](#the-pr-body).
3. Gate, then ask. `just agent ship-ready <n>` waits for CI, then requires the
   PR to be open, not a draft, `mergeStateStatus` `CLEAN` and based on
   `experimental`. On READY, show the printed summary and ask the one
   question. On NOT READY, fix what the gate names and do not ask.
4. Land, on yes only. `just agent ship-land <n>` re-runs the gate, merges
   (rebase for one commit, a merge commit for several), confirms the PR is
   `MERGED`, updates `experimental`, deletes the local and remote branch and
   runs `just close-fixed <n>` (closes issues the PR's closing keywords missed). A failed merge deletes nothing.

On a no, the PR stays open and nothing is cleaned up.

## Stacked PRs

A stacked PR is one whose base is another PR's branch. It must be retargeted
to `experimental` before its base merges. GitHub retargets a stacked PR only
when the base branch is deleted, and the repository deletes a branch as soon
as its PR merges, so no gap is left to retarget afterwards. Retarget with
`gh pr edit <child> --base experimental`. Each PR still gets its own
merge-and-delete question, and the PR body says which PR is stacked on which.

## File issues and PRs only in this repository

File issues and PRs only in `NireBryce/nixos-configs`. An upstream bug (in
nixpkgs or another tool) is still tracked here. Filing on another project
needs the repo owner to ask for that specific filing in their own message.
Approving a list of tasks that includes one does not count.

Drafts written for other projects stay in
`_loose-ends/bugs-pending-submission/` and `wiki/meta/open-threads.md` for
the repo owner to file. A filing here can still notify another project through
GitHub autolinking of `owner/repo#123`, so grep for that pattern before
filing. The skill `propose-issue` hardcodes `--repo NireBryce/nixos-configs`
in its `gh issue create`.

## The PR body

A PR body follows `.github/PULL_REQUEST_TEMPLATE.md`, with the sections
"What changed", "Why", "Verified" and "Deliberately left alone". Delete any
section that does not apply; do not leave a placeholder. "Verified" is for
what CI cannot check, such as a `just switch` on a host or a `drvPath`
comparison against unaffected hosts.

When an agent wrote the PR, the disclosure line `🤖 Generated by an LLM agent`
goes before "What changed" and again at the bottom. A harness-injected footer
counts as the bottom one. The line names no model, for the same reason as the
trailer. For a change to a guard or check, the body says what is now enforced
and how it was verified. It does not say which inputs got past the old
version.

## Say which rung you reached

A session reports the highest verification rung it reached and claims nothing
beyond it. The rungs, each catching defects the one before cannot:

- *Evaluates*: `nix eval` of a toplevel `drvPath`, or `just check`.
- *Builds*: `just build`; `nix build --dry-run` gives the plan without
  compiling.
- *Runs*: switched on the host and used.
- For a setting that renders into a file: the rendered file was read.

An undated "verified" counts as *evaluates*. Evaluating a cheap attribute
proves nothing; force a toplevel. A clean build still stops short of runtime.
A NixOS host can be built only on itself, because there is no remote builder
and no binfmt. See [lesson 18](../../wiki/agent-lessons-learned/18-say-which-rung.md).

## A session without nix or `just`

Some cloud sessions have nix but cannot fetch the flake inputs, and have no
`just`. Such a session still runs the checks that need neither, through
`flake/scripts/offline_checks.py`. The git hooks detect the situation from
`flake/scripts/with-nix-tools.sh` exiting 75, and then:

- `pre-commit` runs `offline_checks.py staged`: staged `.py` files compile,
  shell scripts pass `bash -n`, `.json` and `.toml` parse, `.nix` passes
  `nix-instantiate --parse`, and the wiki lint runs without its `generated`
  check.
- `pre-push` runs `offline_checks.py preflight`: every `python3` step of the
  preflight recipe, with the nix-dependent steps named and left to CI.

`just preflight-offline` runs the same set by hand where `just` exists. The
[offline checks](glossary.md#offline-checks) stand in for statix and deadnix
but do not match them, so CI still has to catch a lint regression. Such a
session reaches no rung above the offline checks, and says so.

## Worked example: a one-page docs fix

The example fixes a wrong command on one wiki page and lands it. Run each
command from inside the worktree once it exists; `<repo>` is the shared
checkout and `<scratch>` the session's scratch directory.

1. Check where the session is. The output names the branch and dirty paths.

   ```sh
   hostname
   just agent where
   ```

2. Create a worktree. It prints `<scratch>/wt-fix-wiki-command`.

   ```sh
   just agent worktree new docs/fix-wiki-command --root <scratch>
   ```

3. Find whether the problem is already tracked.

   ```sh
   just threads "<keywords>"
   ```

4. Edit the page and its `-for-agents.md` sibling, bump `_Last modified:_` on
   each page whose text changed, and grep for other copies of the wrong
   command (skill `wiki-sync`).

5. Run the wiki lint.

   ```sh
   just wiki-lint
   ```

6. Run preflight.

   ```sh
   just agent preflight-brief
   ```

7. Commit exactly the changed pages. `git log -1` ends with
   `Co-Authored-By: Claude`.

   ```sh
   just agent commit -- wiki/<dir>/<page>.md wiki/<dir>/<page>-for-agents.md <<'EOF'
   docs: fix the <command> invocation on <page>

   What was wrong, what it is now, and that wiki-lint and preflight pass.
   EOF
   ```

8. Write the PR body to a file under the template's headings, with the
   disclosure line at the top and bottom, then open the PR. The command prints
   the PR URL.

   ```sh
   just agent pr <scratch>/pr-body.md
   ```

9. Gate the PR. The output says READY; show the summary to the repo owner and
   ask the single merge-and-delete question.

   ```sh
   just agent ship-ready <n>
   ```

10. On a yes, land it. The output prints `merged #<n> (<method>)`, the detach
    of this worktree and the local `git branch -D`.

    ```sh
    just agent ship-land <n>
    ```

11. Remove the worktree. The git guard asks before `worktree remove --force`;
    it is the `use-a-worktree` skill's documented cleanup step.

    ```sh
    git -C <repo> worktree remove --force <scratch>/wt-fix-wiki-command
    ```

12. Report the landed commit, the branch's fate, and the rung reached. A docs
    change *evaluates* (lint and preflight passed); it does not build or run.

## Sources

- `AGENTS.md`: hard rules, "Working in this repo", "Conventions", "Commands",
  "Before calling it done"
- `.agents/skills/use-a-worktree/SKILL.md`, `.agents/skills/ship/SKILL.md`,
  `.agents/skills/ship/side-flows.md`, `.agents/skills/wiki-sync/SKILL.md`,
  `.agents/skills/propose-issue/SKILL.md`
- `.agents/scripts/worktree.py`, `.agents/scripts/ship.py`,
  `.agents/scripts/agent.just`
- `.agents/settings.json`, `.agents/hooks/session-start.sh`
- `.githooks/pre-commit`, `.githooks/commit-msg`, `.githooks/pre-push`
- `flake/scripts/check_trailers.py`, `flake/scripts/offline_checks.py`,
  `flake/scripts/with-nix-tools.sh`
- `.justfile`, `.github/workflows/check.yml`, `.github/PULL_REQUEST_TEMPLATE.md`
- [18-say-which-rung.md](../../wiki/agent-lessons-learned/18-say-which-rung.md)
