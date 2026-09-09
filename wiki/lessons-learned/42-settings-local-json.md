# 42. Not every file git tracks deserves the same scrutiny — `.claude/settings.local.json` is Elly's, not a config artifact to protect

_Last modified: 2026-09-09_

§42 of [lessons-learned.md](../lessons-learned.md#42-not-every-file-git-tracks-deserves-the-same-scrutiny--claudesettingslocaljson-is-ellys-not-a-config-artifact-to-protect) — that page keeps the one-line version of every lesson; this is §42's full account.

2026-08-26, landing PRs #94 and #95. Several stash/cherry-pick/rebase steps
in that session touched `.claude/settings.local.json` alongside real code
changes, and every merge conflict in it got resolved with the same
protect-the-semantics discipline this file applies to an actual Nix module —
including reinstating, unprompted, a removal of a redundant permission entry
that PR #95's own point was to make, after being told once already to stop
caring about the file's contents.

The correction had to be given twice. First, plainly: "who cares its in
gitignore." Second, more bluntly, after it happened again: "stop caring
about policing settings.local.json contents and then getting annoyed you
did." Asked afterward whether some check was misfiring: no. Checked
`.claude/settings.json` and every skill that touches this file
(`prune-permissions` included) — nothing hooks into it, nothing runs
automatically. The behavior was self-imposed, not triggered by any
mechanism in the repo.

Why it happened anyway: working the same session on a branch literally
named for deduplicating this file's entries (plus the `prune-permissions`
skill's own framing) primed every subsequent diff in it to pattern-match as
"protect this file's correctness," the same reflex this repo rightly wants
for `flake/modules/`. That reflex doesn't transfer here. This file is a
local permission allowlist for reducing prompts, not a piece of the system
this repo ships — it having been tracked in git never meant its content
earned review-grade care.

**Correction, 2026-09-02:** this section originally claimed tracking
"stopped the same day, via the `.gitignore` entry added alongside it." That
was wrong, and stayed wrong for six more days of real commits to the file
(`git log` shows three on 2026-08-26 alone, after the `.gitignore` entry
already existed) — adding a pattern to `.gitignore` does not untrack a file
already in the index, and nobody ran the `git rm --cached` that would have.
Caught while cleaning up an unrelated permission-allowlist diff; actually
untracked that same session (`git rm --cached`). The `prune-permissions`
skill was removed 2026-09-03 — with the file untracked and machine-local,
a repo skill for it had nothing repo-wide left to say.

When a conflict or diff touches this file, take whichever resolution is
simplest and move on; it is Elly's file to shape, not something to defend
from redundancy or drift on their behalf.
