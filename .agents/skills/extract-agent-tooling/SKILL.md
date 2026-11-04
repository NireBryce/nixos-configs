---
name: extract-agent-tooling
description: Records a skill, lesson, wiki convention, script or hook as an extraction candidate when its mechanism would work in any agent-run repo.
when_to_use: Writing or changing a skill, lesson, wiki convention, AGENTS.md section, checker script or hook whose mechanism isn't specific to this repo.
---

# Recording general agent-tooling candidates, as you go

## Applies to

Use this when you write or materially change something agent-facing (a skill, a `wiki/agent-lessons-learned.md` §, a wiki layout or style rule, an AGENTS.md section, a `wiki/meta/scripts/` or `flake/scripts/` checker, a `.agents/hooks/` or `.githooks/` hook) and its mechanism does not depend on this repo. Do not use it for:

- a deliberate pass over the whole tree: `extract-agent-tooling-all`
- something that only makes sense with Nix: `extract-nix-tooling` (same procedure, different folder)
- copying anything into another repo: never, unless the user asks in those words

Candidates go in `_loose-ends/extraction-candidates/agent-orchestration/`, one file per candidate, named `<short-name>.md`.

## The rule

**Record, don't extract.** The output is one candidate file in this repo, committed with the task that surfaced it (the same way a `boyscouting` fix rides along). Do not generalize this repo's copy. The in-repo version keeps its hostnames, paths and incident dates because that specificity is what makes it work here. The candidate file says what generalizing would take.

## The generality test

Restate the thing's one-sentence purpose with every repo noun removed: hostnames, `elly`, `NireBryce`, `experimental`, sops, Nix, `just`, wiki page names. Then:

- **Still true and still useful**: candidate. `fact-hygiene` ("write a fact without it rotting into a false claim") passes; so does the `-for-agents.md` sibling convention plus the lint that keeps pairs in sync.
- **Only true with Nix/flake vocabulary put back**: use `extract-nix-tooling` instead.
- **Only true for this fleet** (a host's boot quirk, a tailnet ACL): not a candidate. Stop.

A thing can split. `trim-history`'s "history lives at the bottom of the file, compressed, never trimmed away" is general; "in a `.nix` module" is the Nix half. Record each half in its own folder and link the two files.

**Evidence ranks candidates.** A convention with a § in `wiki/agent-lessons-learned.md`, an enforcing lint check, or a dated incident behind it is a stronger candidate than one that only reads well. Say which in the file.

## File shape

`_loose-ends/extraction-candidates/<folder>/<short-name>.md`, kebab-case, named for the mechanism rather than the source file (sources get renamed):

```markdown
# <short name>

- **Source:** `<path>` (+ any coupled files — a skill and the lint check
  enforcing it travel together)
- **General kernel:** one sentence, repo nouns stripped.
- **Strip/replace:** the repo-specific parts the extracted form must drop
  or parameterize (paths, recipe names, host lists, dates).
- **Evidence:** agent-lessons-learned §, incident date, or enforcing check — or
  "none yet".
- **Depends on:** other candidate files it presupposes (e.g. `skill-files` lint
  needs `new-skill`'s description rule).
- **Recorded:** YYYY-MM-DD
```

## Steps

1. Finish the actual task first. The candidate is incidental to it.
2. Apply the generality test. If it fails, stop; there is nothing to record.
3. Run `grep -rln '<source path>' _loose-ends/extraction-candidates/` and update an existing file rather than adding a duplicate.
4. Write the file. Keep the "General kernel" line free of secrets, tailnet/host names, and the user's email. The folder is committed, and the secrets guard hooks flag the obvious cases.
5. Mention it as a trailing clause in your report and in the commit message ("also recorded X as an extraction candidate").

## See also

- `extract-agent-tooling-all`: the sweep form; reuses this file shape.
- `extract-nix-tooling`: the Nix-specific twin.
- `agent-scripts`: a different extraction, turning re-typed commands into `just agent` helpers in this repo.
- `boyscouting`: the same ride-along discipline for code fixes.
- `fact-hygiene`: dated facts in the file follow its rules.
