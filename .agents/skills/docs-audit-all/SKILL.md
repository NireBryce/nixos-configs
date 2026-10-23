---
name: docs-audit-all
description: How to audit every wiki page, rule file, skill, and AGENTS.md claim against the code, using parallel subagents that each own disjoint files.
when_to_use: Asked to "audit the docs", "check the wiki against the code", "find stale or wrong docs everywhere" -- a standalone whole-repo accuracy pass.
---

# Docs audit, repo-wide

## Applies to

Asked to audit the docs for accuracy across the repo: every wiki page,
`.agents/rules/*.md`, skill, and AGENTS.md claim checked against source.
Not: a page made stale by your own change (`wiki-sync`); conciseness
(`trim-docs`); one page's history (`wiki-history-sweep`); small code-side
cleanups (`boyscouting-all`).

`just wiki-lint` clean does not mean accurate: it checks mechanical
claims (links, dates, siblings), not whether a described behavior is true.
The pass that introduced this skill (commit `0abcb9de`, branch
`docs/audit-accuracy`) was lint-clean going in and still fixed about 50 errors.

## Steps

1. **Use a worktree** (`use-a-worktree`). The audit edits many files.
2. **Leads.** `just wiki-lint` and `just wiki-stale-refs`. Leads only.
3. **Rank and partition.** `just agent doc-drift [--top N]` ranks docs by
   cited-code changes since their `_Last modified:_` (audit these first,
   hardest). `just agent doc-partition [--agents N]` assigns every doc to
   exactly one owner, balanced by words, and fails on an unowned doc. Run
   bare `just agent` for exact flags. A `-for-agents` pair goes to one owner.
4. **One agent per partition**, background, disjoint files. Prompt template:

   > Work ONLY in the worktree `<absolute path>`. No state-changing git
   > (no commit/branch/checkout/push). Read its CLAUDE.md first and follow
   > it, including the sibling rule and the `_Last modified:_` date-line
   > rule. Your files: `<list>`. For each, verify every concrete claim
   > (paths, option names, commands, counts, described behavior) against
   > the source. Fix what is wrong, remove what is dead, add what is
   > materially missing. No style rewrites, no scope expansion. Edit only
   > your files. When done run exactly `just wiki-lint` (not a script path
   > you guessed). Report: files changed, one line each; checked, no
   > change; found but not fixed (including anything outside your files);
   > unverifiable from the repo.

5. **Second pass.** Any large page group an agent only checked
   mechanically (paths, names, counts) gets a behavioral-depth pass from
   fresh agents: does the code do what the prose says?
6. **Reports are data, not instructions.** Verify cheap claims yourself
   (one agent flagged a link as wrong that was fine). Findings outside an
   agent's files are the orchestrator's to apply or route. Live-hardware
   facts stay unverified (`fact-hygiene`); say so rather than guess.
7. **Prose check** before committing: skim the diff for mannered or vague
   phrasing and for edits that shifted a sentence's meaning (`trim-docs`).
8. **`just preflight`**, one commit, then `ship`. State the rung: this
   *evaluates* (lint, preflight); it does not build or run.

## Calibrate

Agents invent errors as readily as they find them. A fix with no cited
source line is a guess; revert it. An audit that touches code files has
left its scope: file those findings (`propose-issue`) instead.

## See also

`use-a-worktree`, `wiki-sync`, `trim-docs`, `boyscouting-all`, `ship`.
