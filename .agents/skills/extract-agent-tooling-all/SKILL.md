---
name: extract-agent-tooling-all
description: Sweeps the repo for skills, lessons, conventions, scripts and hooks that would work in any agent-run repo, and updates the extraction candidates folder.
when_to_use: Asked what here is worth extracting, what would work in other repos, or to refresh the agent-orchestration extraction candidates.
---

# Sweeping for general agent-tooling candidates

## Applies to

Use when asked to "find what's worth extracting", "what here would work in
other repos", or to refresh `_loose-ends/extraction-candidates/agent-orchestration/`.
This is a standalone pass. It does not cover:

- a candidate noticed while doing something else (use `extract-agent-tooling`,
  in that task's commit);
- the Nix-specific equivalent (`extract-nix-tooling-all`);
- creating, populating, or pushing to the general repo, which happens only
  when the user asks (AGENTS.md, "File issues and PRs only in").

## Relationship to `extract-agent-tooling`

The generality test and file shape are the same; read that skill first, since
they are not repeated here. This skill widens the scope: open every
agent-facing surface, and reconcile existing candidate files instead of only
adding new ones.

## Where to look

Survey these surfaces and judge each item against the test. Use `ls` to see
what currently exists in each; the table says where to look, not what you
will find.

| Surface | Typical candidate shape |
|---|---|
| `AGENTS.md` | Structure and framing (written-by-agents header, canonical file + `CLAUDE.md` symlink, Traps-as-pointers-to-skills, prose conventions) |
| `.agents/skills/` | Skills whose description survives losing "in this repo"; the `.claude/skills` symlink layout itself |
| `wiki/meta/styleguide.md`, `wiki/00-INDEX.md` | Two-audience page pairs, routing index, `-history.md` companions, date lines |
| `wiki/agent-lessons-learned.md` + `wiki/agent-lessons-learned/` | § numbering with per-§ articles; individual lessons whose rule outlives the incident |
| `wiki/meta/scripts/` | Doc linters (`check_restatement.py`, `history_candidates.py`; the generic checker was extracted upstream as [factcheck](https://github.com/NireBryce/factcheck), and this repo's checkers are now its plugins) |
| `flake/scripts/`, `.agents/scripts/` | Non-Nix scripts (`branches.py`, `threads.sh`-style tooling; the `just agent` helpers) |
| `.agents/hooks/`, `.githooks/` | Git/secret guard hooks, the commit-trailer normalizer |
| `.agents/settings.json` (symlinked as `.claude/settings.json`) | Permission and hook wiring patterns |

If an item needs Nix to make sense, note it for the Nix folder
(`extract-nix-tooling-all`) and move on. Do both sweeps at once only when
asked.

## Steps

1. **Use a worktree** (`use-a-worktree`).
2. **Scope with the user** if the ask is vague: all surfaces, or one (skills
   only, wiki conventions only). Ask one question instead of guessing.
3. **Reconcile existing candidates first.** For each file in the folder, check
   that the source still exists (`git-archaeology` if it was renamed) and that
   "General kernel" and "Strip/replace" are still right. Fix or delete the
   file; a dead candidate is a false claim (`fact-hygiene`).
4. **Survey** the surfaces above. To find what "Strip/replace" must cover,
   grep each candidate for repo nouns:
   `grep -nE 'nire-|elly|NireBryce|experimental|sops|just |\.nix' <file>`.
   A file with dozens of hits can still be general in mechanism; the count
   only shows how much stripping the extracted form needs.
5. **Rank the new candidates in your report.** Order by evidence (enforced by
   a check > has an agent-lessons-learned § > has an incident > none) and by
   coupling (a skill and its lint travel as one candidate).
6. **Report** a short table of candidate, kernel, evidence and coupling, plus
   the files you deleted or rewrote and why.
7. **Ship** (`ship`) with one commit for the folder update; it touches no
   source files.

## Calibrate

The folder is a shortlist, not an inventory. If most of the repo seems to
qualify, the test is being applied to topics ("wiki maintenance") instead of
mechanisms ("lint fails when a sibling page's date predates its source's").
Re-apply it at the mechanism level and keep only those.

## See also

- `extract-agent-tooling` — the test and file shape this reuses.
- `extract-nix-tooling-all` — the Nix-specific sweep.
- `boyscouting-all` — the same "deliberate version of an as-you-go skill"
  split.
