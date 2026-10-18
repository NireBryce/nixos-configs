---
name: extract-agent-tooling-all
description: How to sweep the whole repo for skills, lessons, wiki conventions, scripts, and hooks worth extracting to a general agent-orchestration repo, and bring the candidates folder up to date.
when_to_use: Asked what here is worth extracting, what would work in other repos, or to refresh the agent-orchestration extraction candidates.
---

# Sweeping for general agent-tooling candidates

## Applies to

Asked to "find what's worth extracting", "what here would work in other
repos", or to refresh
`_loose-ends/extraction-candidates/agent-orchestration/` — a deliberate,
standalone pass. Not: a candidate noticed while doing something else
(`extract-agent-tooling`, in that task's commit); the Nix-specific
equivalent (`extract-nix-tooling-all`); actually creating, populating, or
pushing to the general repo (only when the user asks in those words —
AGENTS.md's "Never file anything outside").

## Relationship to `extract-agent-tooling`

Same generality test and file shape — read that skill first; they aren't
repeated here. What changes is scope: every agent-facing surface gets
opened deliberately, and existing candidate files get reconciled, not
just added to.

## Where to look

Survey these surfaces, judging each item against the test. Use `ls`, not
this list, for what currently exists in each; the list says where to
look, not what you'll find.

| Surface | Typical candidate shape |
|---|---|
| `AGENTS.md` | Structure and framing (written-by-agents header, canonical file + `CLAUDE.md` symlink, Traps-as-pointers-to-skills, prose conventions) |
| `.agents/skills/` | Skills whose description survives losing "in this repo"; the `.claude/skills` symlink layout itself |
| `wiki/styleguide.md`, `wiki/00-INDEX.md` | Two-audience page pairs, routing index, `-history.md` companions, date lines |
| `wiki/lessons-learned.md` + `wiki/lessons-learned/` | § numbering with per-§ articles; individual lessons whose rule outlives the incident |
| `wiki/scripts/` | Doc linters (`check_wiki.py`'s generic checks, `check_restatement.py`, `history_candidates.py`) |
| `flake/scripts/` | Non-Nix scripts (`branches.py`, `threads.sh`-style tooling) |
| `.claude/hooks/`, `.githooks/` | Git/secret guard hooks, the commit-trailer normalizer |
| `.claude/settings.json` | Permission and hook wiring patterns |

Anything turned up here that needs Nix to make sense goes to the Nix folder
(`extract-nix-tooling-all`) — note it and move on rather than doing both
sweeps at once unless asked.

## Steps

1. **Use a worktree** (`use-a-worktree`).
2. **Scope with the user** if the ask is vague — all surfaces, or one
   (skills only, wiki conventions only). One question, not a guess.
3. **Reconcile existing candidates first.** For each file in the folder: does the
   source still exist (`git-archaeology` if renamed)? Has it changed
   enough that "General kernel" or "Strip/replace" is wrong? Fix or delete
   it — a dead candidate is a false claim (`fact-hygiene`).
4. **Survey** the surfaces above. To get through "Strip/replace" quickly,
   grep each candidate for repo nouns:
   `grep -nE 'nire-|elly|NireBryce|experimental|sops|just |\.nix' <file>`.
   A file with dozens of hits may still be general in mechanism; the count
   only says how much stripping the extracted form needs.
5. **Rank, don't just list.** Order the new candidates in your report by
   evidence
   (enforced by a check > has a lessons-learned § > has an incident >
   none) and by coupling (a skill and its lint travel as one candidate).
6. **Report** a short table — candidate, kernel, evidence, coupling — and
   the files you deleted or rewrote, with why.
7. **Ship** (`ship`) — one commit for the folder update; it touches no
   source files.

## Calibrate

The folder is a shortlist, not an inventory. If most of the repo seems to
qualify, the test is being applied to *topics* ("wiki maintenance") rather
than *mechanisms* ("lint fails when a sibling page's date predates its
source's"). Re-apply it at the mechanism level and keep only those.

## See also

- `extract-agent-tooling` — the test and file shape this reuses.
- `extract-nix-tooling-all` — the Nix-specific sweep.
- `boyscouting-all` — the same "deliberate version of an as-you-go skill"
  split.
