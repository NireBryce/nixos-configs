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

## This repo already has three ways to record a bug, and none is a tracker

Per `AGENTS.md`'s convention, **"a bug recorded in a comment stays in the
file"** (or moves to a `history` heading — `boot-durandal.nix`,
`WARN-impermanence.nix`, `vscode.nix`); `wiki/lessons-learned.md` numbers
how things went wrong in the doing; `wiki/open-threads.md` holds open
questions. All three are records; none make sure the bug gets *worked*.
That's what the issue adds — propose it in addition to whichever of the
three the bug also warrants, not instead. The repo has labels
(`bug`, `documentation`, `enhancement`, …) but no backlog yet, which is
exactly why one bug going unfiled is easy to lose.

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

1. **Verify it, don't recall it.** Re-open the file or re-run the command —
   "bugs here serialize" applies to reporting a bug as much as fixing one.
2. **Check it isn't already tracked.** `just threads "<keywords>"` covers
   GitHub issues plus `wiki/`, `lessons-learned.md` and `bugs pending
   submission/` in one shot; also grep `AGENTS.md` itself, which that
   script doesn't touch. Stop if already covered.
3. **Ask, showing the real content.** Ask with title and a short drafted
   body — the decision lands on actual text, not "should I file
   something?" — and name the label (`bug`, `documentation`, or
   `enhancement`).
4. **On yes:**

   ```sh
   gh issue create --repo NireBryce/nixos-configs \
     --title "..." --label bug \
     --body "..."
   ```

   Body: what's wrong, where (`file:line`), how you noticed, fix sketch if
   obvious. Report the issue URL back in your reply.
5. **On no:** don't file it, say so — and still leave whatever comment or
   `lessons-learned.md` entry the bug warrants. Declining the issue doesn't
   mean the knowledge evaporates too.

## Calibrate

`CLAUDE.md`: "Homelab, not production; the repo has gone six months between
commits." Propose for what would actually bite someone on the next session
or the next boot — not every small wart noticed in passing. Mention the
minor ones in your reply and leave it at that; run this flow only on things
worth Elly's round-trip.
