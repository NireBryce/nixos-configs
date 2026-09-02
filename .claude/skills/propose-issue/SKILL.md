---
name: propose-issue
description: How to propose filing a GitHub issue when you notice a genuine bug in this repo's own config/code/docs while working on something else.
---

# Proposing repo bugs for the issue tracker

## Applies to

You're doing something else — building, reading a module, checking a host —
and you notice an actual defect along the way: a command in a doc that
doesn't work, a config option that no longer exists, a claim in `CLAUDE.md`
or the wiki that the machine now contradicts, dead code. Not something you
were asked to look into (fix that directly and say so), and not a style
opinion (no failure scenario, no issue).

## This repo already has three ways to record a bug, and none of them is a tracker

`CLAUDE.md`'s own convention: **"A bug recorded in a comment stays in the
file"** — fix lands, comment stays, or if the code it described is gone, it
moves to a `history` heading instead of being deleted (`boot-durandal.nix`,
`WARN-impermanence.nix`, `vscode.nix` do this). `wiki/lessons-learned.md`
is the second: numbered entries (currently up to §34) for how something went
wrong in the doing. `wiki/open-threads.md` is the third, for open questions
rather than resolved bugs.

All three are records — they make sure the next reader knows. None of them
make sure the bug gets *worked*. That's what filing a GitHub issue adds, and
it's why this skill exists: propose the issue in addition to whichever of
the three above the bug also warrants, not instead of it. Checked
2026-08-23: `NireBryce/nixos-configs` has labels already
(`bug`, `documentation`, `enhancement`, `question`, `duplicate`, `invalid`,
`wontfix`, `help wanted`, `good first issue`) but zero issues filed — there's
no backlog yet, which is exactly why one bug going unfiled is easy to lose.

## This never extends to a third-party repo

Every `gh issue create` in this skill hardcodes `--repo
NireBryce/nixos-configs`. That's not incidental — this skill files in this
repo only, full stop, even for a bug whose real fix belongs upstream (in
nixpkgs, ble.sh, carapace, whatever). Filing there instead is a different,
heavier action with its own rule in `CLAUDE.md`: never without Elly saying
so explicitly, in those words, unprompted — not satisfied by this skill's
own step 3 ask-the-user confirmation, and not satisfied by folding it into some
other approval. If a bug genuinely belongs upstream, this skill still
applies for tracking it *here* (`bug` label, or note it in
`wiki/open-threads.md`/`bugs pending submission/` if a draft write-up is
what's actually ready); filing it at the third-party project is a separate
ask you make by name, not a step of this flow.

## Why propose instead of just filing

Filing is outward-facing the moment `gh issue create` returns — same reason
the `ship` skill gates a merge, just one confirmation instead of two, since
closing a wrongly-filed issue costs nothing the way an unwound merge does.

## Steps

1. **Verify it, don't recall it.** Re-open the file or re-run the command.
   `CLAUDE.md`: "Bugs here serialize" — the discipline that applies to fixing
   a bug applies to reporting one too; a half-remembered impression is how a
   false one gets filed.
2. **Check it isn't already tracked.** Run `just threads "<keywords>"` — the
   same command `investigate-bug` step 1 uses, and for the same reason: it
   already covers GitHub issues plus `wiki/`, `lessons-learned.md` and
   `bugs pending submission/` in one shot (`flake/scripts/threads.sh`), so
   there's no separate hand-grep to keep in sync with what that script
   covers. Also grep `CLAUDE.md` itself, which threads.sh doesn't touch.
   Stop here if it's already covered.
3. **Ask, showing the real content.** Ask the user (through whatever
   ask/confirm mechanism your harness provides) with the title
   and a short body already drafted — the decision should land on the actual
   text, not on a vague "should I file something?" — and name which label
   you'd use (`bug` for a defect, `documentation` for a doc that's wrong,
   `enhancement` for a gap that isn't strictly broken).
4. **On yes:**

   ```sh
   gh issue create --repo NireBryce/nixos-configs \
     --title "..." --label bug \
     --body "..."
   ```

   Body: what's wrong, where (`file:line`), how you noticed it, and a fix
   sketch if one's obvious. Close it the same way this session's PR bodies
   close, for provenance:

   ```
   🤖 Filed with [Claude Code](https://claude.com/claude-code)
   ```

   Report the issue URL back in your reply.
5. **On no:** don't file it, say so, and still leave whatever comment or
   `lessons-learned.md` entry the bug warrants regardless — declining the
   issue doesn't mean the knowledge should evaporate too.

## Calibrate

`CLAUDE.md`: "Homelab, not production; the repo has gone six months between
commits." Propose for what would actually bite someone on the next session
or the next boot — not every small wart noticed in passing. Mention the
minor ones in your reply and leave it at that; run this flow only on things
worth Elly's round-trip.
