---
name: handoff
description: Hands work to a fresh session by committing it to a branch and opening a PR whose body is the handoff note.
when_to_use: Asked for a handoff, to end or wrap up the session, or to continue in a fresh session, or after a task finishes and the next one is unrelated.
---

# Handing work to a fresh session through a PR

**Needs:** bash-guards

## Applies to

Use this skill when the user asks for a handoff, says to wrap up or start a
new session, or when a task has finished and the next one is different. A long
session re-reads all of its history on every call, so a fresh session that
starts from a PR is cheaper than continuing. The PR holds the state (branch,
commits, checks, comments) and the body holds the reasoning, so nothing has to
be pasted between sessions.

Do not use it to summarize a session for the user's own reading (answer in
chat). Do not use it to land work: "ship it" is skill `ship`, which merges.
A handoff opens the PR and stops.

If there is nothing to commit (a design discussion with no file changes), file
the note as an issue instead, with the same body shape, under skill
`propose-issue`'s rules (this repo only).

## Steps

1. **Check where the work is.** Run `just agent where`. Work in the shared
   checkout moves to a worktree first (skill `use-a-worktree`). Never commit on
   `experimental`.
2. **Commit the work** with `just agent commit -- <paths...>`, naming only the
   paths that belong to this task. A half-finished state is fine on a branch;
   say so in the body. If a dirty path is not yours, leave it and ask.
3. **Write the body to a file** in the scratchpad, in the shape of
   `.github/PULL_REQUEST_TEMPLATE.md`: the `🤖 Co-written by an LLM agent`
   line at top and bottom, then:
   - **What changed**: one line per change.
   - **Why**: the goal, and each decision the user made with its reason,
     including rejected options, so the next session does not reopen them.
   - **Verified**: what was checked and the rung reached (evaluates, builds,
     runs; AGENTS.md "Before calling it done"). Say what was not checked.
   - **Deliberately left alone**: related things not touched, and why.
   - **Open**: questions waiting on the user and anything half done.
   - **Next**: the single next action, as a command or a file to open.
   - **Risk and impact**: scored as `ship` step 1 describes.
4. **Open the PR**: `just agent pr <body-file>` (add `--title T` for several
   commits). To update the note later, `just agent pr <body-file> --edit <n>`.
5. **Give the user the start line** for the new session, with the PR number:
   `Continue PR #<n>: read it with just agent where <n> and gh pr view <n>
   --comments, then do its Next step.` Stop. Do not start the next task here,
   and do not merge.

## Rules

- Say "the user", never their name (AGENTS.md, Conventions).
- The repo is public, so the body holds no secret value, token or decrypted
  sops output (skill `secrets-hygiene`), and no security or threat-model
  detail; that goes to `elly/infra-notes` (AGENTS.md, Working in this repo).
- Name state by pointer (a PR, a branch, a path), not by copied value; a copied
  value goes stale (skill `fact-hygiene`).
- Leave out command output, file contents and the order things happened in.
  The next session can read the diff; it cannot recover a decision.
- Keep the body under about 40 lines apart from the template headings.

## Picking it up

The new session reads the PR, not this session. Start with `just agent where
<n>`, then `gh pr view <n> --comments`. Treat **Why** as settled unless the
user reopens it, and check **Verified** against the diff before relying on it.
Continuing the work adds commits to the same branch (in a worktree) and edits
the body with `--edit` when the state changes.

## See also

Skill `ship` (merging the PR the handoff opened), skill `use-a-worktree`,
`.github/PULL_REQUEST_TEMPLATE.md`.
