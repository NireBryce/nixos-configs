---
name: extract-agent-tooling
description: How to notice, while creating or editing a skill, lesson, wiki convention, script, or hook, that its mechanism would serve any agent-worked repo, and record it as an extraction candidate.
when_to_use: Writing or changing a skill, lesson, wiki convention, AGENTS.md section, checker script, or hook whose mechanism would work in any repo.
---

# Recording general agent-tooling candidates, as you go

## Applies to

You are writing or materially changing something agent-facing — a skill, a
`wiki/lessons-learned.md` §, a wiki layout or style rule, an AGENTS.md
section, a `wiki/scripts/` or `flake/scripts/` checker, a `.claude/hooks/`
or `.githooks/` hook — and notice its *mechanism* doesn't depend on this
repo. Not: a deliberate pass over the whole tree (`extract-agent-tooling-all`);
something that only makes sense with Nix in the picture
(`extract-nix-tooling` — same procedure, different folder); actually
copying anything into another repo (never, unless the user asks in those
words).

Candidates go in `_loose-ends/extraction-candidates/agent-orchestration/`,
one file per candidate, named `<short-name>.md`.

## The rule

**Record, don't extract.** The output is one candidate file in this repo,
riding in the same commit as the task that surfaced it — the way a
`boyscouting` fix rides along. Don't generalize this repo's copy while
you're at it: the in-repo version keeps its hostnames, paths, and incident
dates, because that specificity is what makes it work *here*. The
genericized form is the future repo's problem; the file just says what it
would take.

## The generality test

Restate the thing's one-sentence purpose with every repo noun removed —
hostnames, `elly`, `NireBryce`, `experimental`, sops, Nix, `just`, wiki
page names. Then:

- **Still true and still useful** → candidate. `fact-hygiene` ("write a
  fact without it rotting into a false claim") passes; so does the
  `-for-agents.md` sibling convention plus the lint that keeps pairs in
  sync.
- **Only true with Nix/flake vocabulary put back** → `extract-nix-tooling`
  instead.
- **Only true for this fleet** (a host's boot quirk, a tailnet ACL) →
  not a candidate; stop.

A thing can split: `trim-history`'s "history lives at the bottom of the
file, compressed, never trimmed away" is general; "in a `.nix` module" is
the Nix half. Record each half in its own folder and link the two files.

**Evidence beats elegance.** A convention that has a § in
`wiki/lessons-learned.md`, a lint check enforcing it, or a dated incident
behind it is a much stronger candidate than one that merely reads well —
say which in the file.

## File shape

`_loose-ends/extraction-candidates/<folder>/<short-name>.md` — kebab-case,
named for the mechanism, not the source file (sources get renamed):

```markdown
# <short name>

- **Source:** `<path>` (+ any coupled files — a skill and the lint check
  enforcing it travel together)
- **General kernel:** one sentence, repo nouns stripped.
- **Strip/replace:** the repo-specific parts the extracted form must drop
  or parameterize (paths, recipe names, host lists, dates).
- **Evidence:** lessons-learned §, incident date, or enforcing check — or
  "none yet".
- **Depends on:** other candidate files it presupposes (e.g. `skill-files` lint
  needs `new-skill`'s description rule).
- **Recorded:** YYYY-MM-DD
```

## Steps

1. Finish the actual task first; the candidate is incidental to it.
2. Apply the generality test. Fails → stop, nothing to record.
3. `grep -rln '<source path>' _loose-ends/extraction-candidates/` — update
   an existing file rather than adding a duplicate.
4. Write the file. Keep the "General kernel" line free of secrets,
   tailnet/host names, and the user's email; the folder is committed, and
   the secrets guard hooks will flag the obvious ones anyway.
5. Mention it in your report as a trailing clause ("also recorded X as an
   extraction candidate"), and in the commit message the same way.

## See also

- `extract-agent-tooling-all` — the sweep form; reuses this file shape.
- `extract-nix-tooling` — the Nix-specific twin.
- `agent-scripts` — a different extraction: re-typed commands into
  `just agent` helpers in this repo, not candidates for another repo.
- `boyscouting` — the same ride-along discipline for code fixes.
- `fact-hygiene` — dated facts in the file follow its rules.
