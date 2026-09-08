## what shipped

Two traps CLAUDE.md already documented in prose, turned into things that
actually fire instead of things a session has to remember:

**"`git add` before `nix eval`"** — a new module that isn't tracked yet is
invisible to the flake, no error, it just doesn't exist. `modules.py` got an
`untracked` check (folded into `just modules`): greps `git status
--porcelain` under `modules/` for any untracked `.nix` file and fails
naming it. Tested by dropping a scratch `.nix` file under
`flake/modules/nire/hardware/` and confirming the check caught it before
deleting it again.

**The commit trailer, `Co-Authored-By: Claude <noreply@anthropic.com>`, no
model name** — CLAUDE.md already explains why this keeps going wrong (the
model name is copied from the system prompt, which an agent has no way to
verify is even correct — 82 wrong "Sonnet 5" trailers and 54 wrong "Opus 5"
ones in the log already). Re-reading the message before committing can't
catch this, because the agent believes the wrong name is true. So instead:
`.githooks/commit-msg`, which rewrites `Claude <anything> <noreply@…>` down
to the canonical form automatically. Tested against both a wrong trailer
(corrected) and an already-correct one (left alone, silent).

Both hooks live in `.githooks/`, opt-in per clone via `just install-hooks`.

## why these two are local-hook territory, not just CI

`untracked` only means anything against a real local working tree — a CI
checkout is always fully tracked (it's a checkout of a git ref), so the
check runs there too via `just modules` but has nothing to ever catch. It
does its real work locally, right before the moment it would otherwise bite.

The commit-msg fix is local-only by necessity: by the time CI sees a commit,
the message is already permanent. There's no "fix it in CI" for text that's
supposed to be corrected before it's written down.
