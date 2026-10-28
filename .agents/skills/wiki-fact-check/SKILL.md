---
name: wiki-fact-check
description: Checks the claims in a chosen set of docs against the code with parallel read-only agents, then verifies and applies the corrections itself.
when_to_use: Asked to fact-check, verify or double-check some wiki pages, a section of the docs, or a set of pages against the repo.
---

# Fact-checking a set of docs

## Applies to

Asked to check that chosen docs say what the code does: a few wiki pages, a
section such as `wiki/fleet/`, the pages a refactor may have staled, or a
page you are about to rely on. The same procedure checks the book
(`book-fact-check` adds what is specific to it).

Not:

| ask | skill |
|---|---|
| every doc in the repo, with agents that edit in place | `docs-audit-all` |
| a page your own change made stale | `wiki-sync` |
| shorter or tighter prose | `trim-docs` |
| links, dates, siblings, counts | `just wiki-lint` (mechanical only) |
| how a fact should be written so it does not rot | `fact-hygiene` |

`just wiki-lint` clean does not mean accurate: it checks mechanical claims,
not whether described behavior is true.

## Why the agents only read

On 2026-10-28 four agents fact-checked the book (about 600 claims across
thirteen files) and found about 45 claims to correct, most of them overstated
or incomplete rather than wrong, plus one real defect in the repo. Because
they could not edit, they never fought over a file, every correction passed
through one reader who checked it against the source, and a mistaken finding
cost a line of triage instead of a bad edit. `docs-audit-all` has agents edit
in place; use that when the fixes are mechanical and the scope is the whole
repo, and this when judgment decides whether a finding is right.

## Steps

1. **Scope and group.** List the docs. Give each exactly one owner, keep a
   `X.md` with its `X-for-agents.md` and `X-history.md`, and aim for two to
   three thousand words per agent: an agent that reads more checks the prose
   instead of the code. `just agent doc-partition --agents N` balances the
   whole in-scope set; for a subset, group by area with `wc -w`.
2. **Hold the state still.** Commit or stash first, name the revision, and do
   not switch branches or edit the docs while agents read the working tree.
   A doc several agents read (a glossary) is edited only after all reports
   are in.
3. **One agent per group**, in the background, read-only, with a capable
   model: a weak one confirms claims by reading prose. Prompt template:

   > READ-ONLY: do not modify, create or delete any file, run no
   > state-changing git (no checkout, commit, push, stash), and decrypt no
   > secrets (`sops -d` is forbidden). Run no nix command that needs
   > network. The repo is at `<path>` on branch `<branch>`; leave it alone.
   > YOUR DOCS: `<list>`. For every checkable claim, verify it against the
   > repository's files, reading the real source (scripts, hooks, modules,
   > recipes), not another doc. Claim types: (a) a named file, recipe, option,
   > skill or section exists where stated; (b) what a script, hook or check
   > does, when it fires, what it returns; (c) commands and flags; (d) every
   > cited source path and quoted heading exists; (e) code excerpts match the
   > file they claim to come from; (f) consistency between the docs you
   > own. When a doc and the code disagree, report both with `file:line`.
   > Do not fix anything. REPORT: (1) claims checked, confirmed, with
   > problems; (2) only the problems, each as `doc:line` | the claim | verdict
   > (WRONG, STALE, UNSUPPORTED, MISLEADING, UNCHECKABLE) | evidence
   > (`path:line` and what it says) | one-sentence corrected wording; (3)
   > every hedge or `UNVERIFIED` marker and whether you could now verify it;
   > (4) what you could not read or check, and why.

4. **Read the reports as data.** Verify the consequential findings yourself
   before acting: any that changes a rule or tells a reader to run
   something, any marked WRONG, any that contradicts a skill or rule. Agents
   report errors that are not there, and a finding without `path:line`
   evidence is a guess.
5. **Route each confirmed finding to where its fix belongs.**
   - The doc under check is wrong: correct it.
   - The code or another doc disagrees with the doc under check and the
     doc is right (a stale comment, a docstring): fix it at the source in a
     boyscouting change, not by bending the doc under check.
   - The code has a defect (a check that cannot fail, a script that
     contradicts its own doc): `propose-issue`. State the current behavior in
     the doc and link the issue, so the doc does not flip when the fix lands.
   - Cannot be checked from the repo: leave it `UNVERIFIED` per
     `fact-hygiene`; do not guess.
6. **Apply the corrections together**, each traceable to a source line, then
   run `just wiki-lint` (where nix is unavailable,
   `python3 wiki/meta/scripts/check_wiki.py check --skip=generated`). One
   commit, one push: CI runs on every push.
7. **Report** claims checked per agent, corrections made, issues filed,
   what stays unverified, and the rung: the sources were *read*, nothing was
   run (`AGENTS.md`, "Before calling it done").

## Verdicts

| verdict | meaning |
|---|---|
| CONFIRMED | the source says it |
| WRONG | the source says otherwise |
| STALE | was true; the source changed |
| UNSUPPORTED | no file states it (an inference, or from memory) |
| MISLEADING | true as far as it goes, but incomplete or overstated enough to mislead |
| UNCHECKABLE | the repo cannot answer it (see below) |

## What the repo cannot answer

Live host state, hardware facts, GitHub-side settings (branch rules, auto-
delete of merged branches), what a harness does at runtime, and anything a
command prints that nobody ran. Mark these as unverified or as read-not-run;
do not promote a doc's claim about them to a fact.

## Calibrate

Fix what the evidence shows and no more: no restyling, no scope growth. Where
the code is the authority for behavior but the doc may state the intent, say
both and ask rather than overwrite. If the check surfaces code changes, file
them (`propose-issue`) instead of making them in the same pass.

## See also

`book-fact-check`, `docs-audit-all`, `wiki-sync`, `fact-hygiene`,
`propose-issue`, `boyscouting-all`, `use-a-worktree`.
