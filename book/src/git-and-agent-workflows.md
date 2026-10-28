# Git and agent workflows

This chapter follows one change through the repo's working loop: its own
worktree, commits with a provenance trailer, the checks that run at commit
and push, preflight, and the `ship` skill's route to a merged PR. It also
covers what "push" means here, where issues and PRs may be filed, how a
session reports what it verified, and how a session without nix still gets
checked. It ends with a worked example from first edit to merged PR.

## One worktree per task

Work that will branch, commit or check out happens in its own
[worktree](glossary.md#worktree), not in the shared checkout. A worktree has
its own directory and `HEAD` and shares the repository's branches and
objects, so two sessions in one repo no longer see each other's checkouts
and commits mid-task. Read-only work (reading files, `just check` on what is
checked out) needs no worktree, and neither does work in the shared checkout
when the user says to work there.

Create one with the helper, which fetches `origin` first and refuses an
existing branch or path:

```sh
just agent worktree new <branch> [<base>] --root <scratch-dir>
```

The base defaults to `origin/experimental`. The worktree lands at
`<scratch-dir>/wt-<branch>`, with any leading `feat/`-style component
dropped, and the command prints only that path. `$AGENT_SCRATCH` can stand in
for `--root`. Under Claude Code, a subagent can get its own worktree by
passing `isolation: "worktree"` to the Agent tool.

Clean up with `git worktree remove --force <path>` once the work has shipped
or been abandoned. `just agent worktree prune --root <dir>` reports each
linked worktree under `<dir>` and, with `--yes`, removes only clean ones whose
commits have landed, or that have no commits ahead, were never pushed, and have
sat untouched past `--min-age` (60 minutes by default). It never removes a dirty worktree or the main checkout.

Check: `just agent where` (or `git status -sb`) inside the new directory shows
the new branch. The session-start hook also reports whether the current
directory is a linked worktree or the shared checkout.

Source: `.agents/skills/use-a-worktree/SKILL.md`; `.agents/scripts/worktree.py`,
docstring; `AGENTS.md`, "Working in this repo";
`.agents/hooks/session-start.sh`.

## Branch names

A branch name and the first line of each commit start with a type prefix:
`feat/`, `fix/` or `docs:` style. The prefix applies to the first line only;
the commit body stays a what, why and verified narrative. The worktree helper
strips the branch's first prefix component to name the directory.

Source: `.agents/skills/ship/SKILL.md`, step 1;
`.agents/scripts/worktree.py`, docstring.

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

The helper refuses to commit without a pathspec, because a bare `git commit`
takes whatever is staged at that moment. It refuses to commit on
`experimental` or `main`, since work lands there only through a PR. It
appends `Co-Authored-By: <agent>` (default `Claude`, or `--agent <name>`)
unless the message already has a `Co-Authored-By` trailer, and warns when
that trailer carries an email or a model name.

The trailer names the agent only, with no model name and no email, because an
agent cannot verify which model is executing it; the trailer records what it
knows. Three layers hold the convention:

1. `attribution.commit` in `.agents/settings.json` makes Claude Code ask for
   `Co-Authored-By: Claude`.
2. `.githooks/commit-msg` rewrites a Claude trailer that carries a model name
   or email into the canonical form.
3. `check_trailers.py` fails a PR in CI that still carries a non-canonical
   Claude trailer.

Another agent's trailer passes through all three, so that agent must form it
correctly when it writes the commit.

Check: `git log -1` shows the trailer as the last line of the message.

Source: `.agents/scripts/ship.py`, docstring (`commit`);
`.agents/skills/ship/SKILL.md`, step 1; `AGENTS.md`, "Conventions";
`.agents/settings.json`; `.githooks/commit-msg`;
`flake/scripts/check_trailers.py`, docstring.

## `git add` before `nix eval`

A new file must be staged before any evaluation, because a flake in a git
repository ignores untracked files and the new module silently does not
exist. `just add-module` stages the file it creates. Hooks remind at the
moment of the mistake: the edit-check hook when an untracked `.nix` file
under `flake/modules/` is written, and the untracked-nix guard when an
evaluating command runs while untracked `.nix` files exist. `just modules`
reports untracked files at preflight.

Source: `AGENTS.md`, "Working in this repo";
`.agents/hooks/edit-check-posttooluse.sh`;
`.agents/hooks/nix-untracked-guard-pretooluse.sh`; `flake/scripts/modules.py`,
docstring.

## What runs at commit and push

Once `core.hooksPath` points at `.githooks`, each commit runs the lint ratchet
and each push without nix runs the offline preflight steps. The session-start
hook sets `core.hooksPath` when it is unset; `just install-hooks` does the
same by hand.

| Moment | Hook | Where nix works | Where nix cannot run |
|---|---|---|---|
| `git commit` | `pre-commit` | [Lint ratchet](glossary.md#lint-ratchet); stages a lowered baseline | `offline_checks.py staged` |
| `git commit` | `commit-msg` | Trailer rewrite | Trailer rewrite |
| `git push` | `pre-push` | Nothing; preflight is the checklist | `offline_checks.py preflight` |

A failing hook stops the commit or push. `--no-verify` bypasses the hooks;
`AGENTS.md` says it should not be needed, and CI runs the same checks
regardless.

Source: `.githooks/pre-commit`, `.githooks/commit-msg`, `.githooks/pre-push`;
`AGENTS.md`, "Commands".

## Preflight is the CI checklist

[Preflight](glossary.md#preflight) is the `just preflight` recipe, and CI runs
that recipe itself rather than a copy of its steps. The recipe runs the fast
checks first (the wiki lint and the test suites), then `just check`,
`just modules` and `just lint`; `just --show preflight` lists the current
steps. `.github/workflows/check.yml` installs nix and runs `nix develop ./flake
--command just preflight`. On a pull request it also runs `check_trailers.py`
over the PR's own commits. `just preflight-mirror-test`, itself a preflight
step, fails if the workflow stops calling the recipe or adds checks of its
own beyond the CI-only ones. A step added to the recipe therefore gates PRs
with no edit to the workflow.

`just agent preflight-brief` runs the same steps concurrently (`just lint`
last, alone) and prints one line per step, with the tail of any failure. For a branch with several
commits, `just agent preflight-each [<range>]` runs it on each commit in a
throwaway detached worktree, because each commit must be green on its own.

Source: `.justfile`, `preflight` and `preflight-mirror-test`;
`.github/workflows/check.yml`, header and steps; `.agents/scripts/agent.just`;
`.agents/skills/ship/SKILL.md`, step 0.

## What "push" means

A bare "push", "ship it", "land this" or "merge this" means the `ship` skill,
landing on `experimental`, the default branch. `main` is the promoted
known-good branch and moves only by a PR from `experimental` after hardware
verification. Other asks map differently:

| The user says | The agent does |
|---|---|
| "push this branch" | `git push` it; no PR, no gates |
| "open a PR" | Opens it and stops |
| "commit this" | Commits; pushing was not asked for |
| "promote to main" | The promotion flow: a PR from `experimental` to `main`, merged with a merge commit |
| a branch named outright | Pushes directly there, except `main` |

When unsure whether an ask means `experimental`, the agent asks.

Source: `AGENTS.md`, hard rules and "Working in this repo";
`.agents/skills/ship/SKILL.md`, "Applies to";
`.agents/skills/ship/side-flows.md`.

## The ship flow

The `ship` skill lands work on `experimental` through a branch, a PR, one
combined question to the user, the merge and the branch deletion.

1. **Fetch and check.** `just agent where` fetches and prints the branch,
   dirty paths, commits and diff stat against `origin/experimental`. Then
   `just agent preflight-brief`, and `just agent preflight-each` for a
   multi-commit branch.
2. **Branch, commit, open the PR.** Commit with `just agent commit`, write
   the PR body to a file, and run `just agent pr <body-file>`. The helper
   pushes with `-u` when the branch has no `origin/<branch>` upstream and
   runs `gh pr create --base experimental --body-file`. It refuses on
   `experimental` or `main` and refuses a body missing the disclosure line.
3. **Gate, then ask.** `just agent ship-ready <n>` waits for CI, then
   requires the PR to be open, not a draft, `mergeStateStatus` `CLEAN` and
   based on `experimental`. `mergeable` alone is not enough, because it means
   only "no conflicts". On READY the agent shows the printed summary and asks
   one question covering both actions: merge, and delete the branch
   afterward? On NOT READY it fixes what the gate names instead of asking.
4. **Land, on yes only.** `just agent ship-land <n>` re-runs the gate,
   merges (rebase for one commit, a merge commit for several, pinned to the
   head commit the gate read), confirms the PR is `MERGED`, then checks out
   and pulls `experimental` (from a linked worktree it detaches that
   worktree instead and leaves the shared checkout alone), deletes the local and remote branch, and runs `just
   close-fixed <n>`. A failed merge deletes nothing.

On a no, the PR stays open and nothing is cleaned up.

Source: `.agents/skills/ship/SKILL.md`, steps 0 to 3; `.agents/scripts/ship.py`,
docstring.

## Stacked PRs

A stacked PR, one whose base is another PR's branch, must be retargeted to
`experimental` before its base merges. GitHub retargets a stacked PR only
when the base branch is deleted, and the repository deletes a branch as soon
as its PR merges, so no gap is left in which to retarget afterwards. Retarget
with `gh pr edit <child> --base experimental`. Each
PR still gets its own merge-and-delete question, and the agent says which PR
is stacked on which.

Source: `.agents/skills/ship/side-flows.md`, "When one working tree becomes
two PRs".

## File issues and PRs only in this repository

Agents file issues and PRs only in `NireBryce/nixos-configs`. An upstream bug
(in nixpkgs or another tool) is still tracked here. Filing on another project
needs the user to ask for that specific filing in their own message; approving
a list of tasks that includes one does not count. Drafts written for other
projects stay in `_loose-ends/bugs-pending-submission/` and
`wiki/meta/open-threads.md` for the user to file. A filing here can still
notify another project through GitHub autolinking of `owner/repo#123`, so the
agent greps for that pattern before filing. The skill `propose-issue`
hardcodes `--repo NireBryce/nixos-configs` in its `gh issue create`.

Source: `AGENTS.md`, hard rules and "Working in this repo";
`.agents/skills/propose-issue/SKILL.md`, "Never a third-party repo".

## The PR body

A PR body follows `.github/PULL_REQUEST_TEMPLATE.md`: "What changed", "Why",
"Verified" and "Deliberately left alone", with any section that does not
apply deleted rather than left as placeholder. "Verified" is for what CI
cannot check, such as a real `just switch` on a host or a `drvPath` comparison
against unaffected hosts. 
When an agent wrote the PR, the disclosure line `🤖 Generated by an LLM agent`
goes before "What changed" and again at the bottom; a harness-injected footer
counts at the bottom. The line names no model, for the same reason as the
trailer. For a change to a guard or check,
the body says what is now enforced and how it was verified, and nothing
about which inputs got past the old version.

Source: `.github/PULL_REQUEST_TEMPLATE.md`; `.agents/skills/ship/SKILL.md`,
step 1; `.agents/scripts/ship.py`, docstring (`pr`); `AGENTS.md`, "Working in
this repo".

## Say which rung you reached

A session reports the highest verification rung it reached and claims nothing
beyond it. The rungs, each catching defects the one before cannot:

- **Evaluates**: `nix eval` of a toplevel `drvPath`, or `just check`.
- **Builds**: `just build`; `nix build --dry-run` gives the plan without
  compiling.
- **Runs**: switched on the host and used.
- For a setting that renders into a file: the rendered file was read.

An undated "verified" counts as *evaluates*. Evaluating a cheap attribute
proves nothing; force a toplevel. A clean build still stops short of runtime.
A NixOS host can be built only on itself, because there is no remote builder
and no binfmt.

Source: `AGENTS.md`, "Before calling it done" and "Commands";
[18-say-which-rung.md](../../wiki/agent-lessons-learned/18-say-which-rung.md).

## A session without nix or `just`

A cloud session that has nix but cannot fetch the flake inputs, and has no
`just`, still runs the checks that need neither, through
`flake/scripts/offline_checks.py`. The git hooks detect the situation from
`flake/scripts/with-nix-tools.sh` exiting 75, and then:

- `pre-commit` runs `offline_checks.py staged`: staged `.py` files compile,
  shell scripts pass `bash -n`, `.json` and `.toml` parse, `.nix` passes
  `nix-instantiate --parse`, and the wiki lint runs without its `generated`
  check.
- `pre-push` runs `offline_checks.py preflight`: every `python3` step of the
  preflight recipe, read from the recipe itself, with the nix-dependent
  steps named and left to CI.

`just preflight-offline` runs the same set by hand where `just` exists. These
[offline checks](glossary.md#offline-checks) replace statix and deadnix
without equalling them, so CI still has to catch a lint regression. Such a
session reaches no rung above the offline checks, and says so.

Source: `flake/scripts/offline_checks.py`, docstring; `.githooks/pre-commit`;
`.githooks/pre-push`; `flake/scripts/with-nix-tools.sh`; `AGENTS.md`,
"Commands".

## Worked example: a one-page docs fix

The example fixes a wrong command on one wiki page and lands it. Run each
command from inside the worktree once it exists; `<repo>` is the shared
checkout and `<scratch>` the session's scratch directory.

1. Check where the session is.

   ```sh
   hostname
   just agent where
   ```

   Check: the output names the branch and the dirty paths of the current
   checkout, and the session-start context says whether this is the shared
   checkout.

2. Create a worktree for the task.

   ```sh
   just agent worktree new docs/fix-wiki-command --root <scratch>
   ```

   Check: the command prints `<scratch>/wt-fix-wiki-command`, and `git -C
   <scratch>/wt-fix-wiki-command status -sb` shows `docs/fix-wiki-command`.

3. Find whether the problem is already tracked.

   ```sh
   just threads "<keywords>"
   ```

   Check: no open issue or wiki thread already covers it.

4. Edit the page and its `-for-agents.md` sibling, bump `_Last modified:_` on
   each page whose text changed, and grep for other copies of the wrong
   command (skill `wiki-sync`).

   Check: the edit-check hook reports no stale sibling for the pair.

5. Run the wiki lint.

   ```sh
   just wiki-lint
   ```

   Check: no hard findings.

6. Run preflight.

   ```sh
   just agent preflight-brief
   ```

   Check: every step prints as passing.

7. Commit exactly the changed pages.

   ```sh
   just agent commit -- wiki/<dir>/<page>.md wiki/<dir>/<page>-for-agents.md <<'EOF'
   docs: fix the <command> invocation on <page>

   What was wrong, what it is now, and that wiki-lint and preflight pass.
   EOF
   ```

   Check: `git log -1` ends with `Co-Authored-By: Claude`.

8. Write the PR body to a file under the template's headings, with the
   disclosure line at the top and bottom, then open the PR.

   ```sh
   just agent pr <scratch>/pr-body.md
   ```

   Check: the command prints the PR URL, and the PR's base is `experimental`.

9. Gate the PR.

   ```sh
   just agent ship-ready <n>
   ```

   Check: the output says READY. Show the summary to the user and ask the
   single question: merge, and delete the branch afterward?

10. On a yes, land it.

    ```sh
    just agent ship-land <n>
    ```

    Check: the output prints `merged #<n> (<method>)`, the detach of this
    worktree and the local `git branch -D`. The remote branch is usually
    already gone.

11. Remove the worktree.

    ```sh
    git -C <repo> worktree remove --force <scratch>/wt-fix-wiki-command
    ```

    The git guard asks before `worktree remove --force`; it is the
    `use-a-worktree` skill's documented cleanup step.

    Check: `git -C <repo> worktree list` no longer shows it.

12. Report the result: the landed commit (rebased, for a single-commit PR),
    the branch's fate, and the rung reached. A docs change *evaluates* (lint and preflight passed); it does
    not build or run.

Source: `.agents/skills/use-a-worktree/SKILL.md`; `.agents/skills/ship/SKILL.md`;
`.agents/skills/wiki-sync/SKILL.md`; `.agents/skills/propose-issue/SKILL.md`,
step 2; `.agents/scripts/agent.just`; `.agents/skills/docs-audit-all/SKILL.md`,
step 8.
