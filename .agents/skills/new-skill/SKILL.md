---
name: new-skill
description: How to write a new SKILL.md in this repo, or fix an existing skill's frontmatter description that undersells or overclaims it.
when_to_use: Creating a SKILL.md, or editing any skill's description or when_to_use.
---

# Writing a new skill

## Applies to

Creating a new `.agents/skills/<name>/SKILL.md` in this repo, or editing an
existing one's frontmatter `description` or `when_to_use`. Not for editing
a skill's body content alone — only touch this when the frontmatter needs
to change too.

## The rule

Three places, three jobs:

| Where | Holds | Who sees it |
|---|---|---|
| `description` | **One sentence: what the skill does or is for.** No file paths, no parenthetical scope lists, no trigger conditions. | Every harness's skill listing |
| `when_to_use` (optional) | Short trigger phrases a user or task would actually say — one line, comma-separated, or a short sentence. | Claude Code only: appended to `description` in its listing |
| `## Applies to` (right after the H1) | The full trigger detail: triggers, non-triggers, exceptions, examples. | Anyone who loaded the skill |

Why: the live skill listing a session sees shows only frontmatter, and
that's the only information available when deciding whether to load a
skill. A description stuffed with scope caveats reads as noise there;
`when_to_use` is where the phrases that should fire it go, kept apart so
the description stays a statement of purpose. Other harnesses (ZCode,
opencode) ignore `when_to_use`, so nothing may live *only* there —
`## Applies to` stays the complete trigger list. The body loads in full
once the skill fires, so detail there costs nothing.

Add `when_to_use` where a missed trigger has actually cost something
(`ship`'s bare "push", `secrets-hygiene`'s `sops` commands) or `## Applies
to` names concrete phrases the description doesn't. Skip it when the
description already says it all. Derive the phrases from `## Applies to`
and AGENTS.md, don't widen scope. Claude Code truncates description +
`when_to_use` at 1,536 chars combined (code.claude.com/docs/en/skills,
checked 2026-10-01). Both values must be plain YAML scalars: never open
with a quote (`"push", "ship it"` parses as a quoted string plus junk —
lead with a word, e.g. `A bare "push", ...`), and no `: ` or ` #` inside.

`just wiki-lint`'s `skill-files` check enforces the mechanical half of
this — description: one sentence, no repo paths, no parentheticals
(wordiness is a REVIEW finding only); `when_to_use`: one line, no repo
paths, under the combined cap (over 40 words is REVIEW); both plain YAML
scalars; no frontmatter keys beyond `name`/`description`/`when_to_use`
(a misspelt `when-to-use` is silently ignored by every harness) — so
frontmatter that drifts from the rule fails the run instead of waiting for
a reader to notice.

Prefer active "How to `<verb>`…" phrasing for a procedural skill over a
"Known traps in…" noun phrase — "traps" reads as scope, not purpose (the user
rejected the latter for `new-flake-module` on 2026-08-22; the accepted form
is that skill's current description). A short flow description without
literal "How to" wording is fine (`ship`'s) as long as it states purpose.

## Steps

1. **Pick a name**: kebab-case, matching the directory exactly
   (`.agents/skills/<name>/SKILL.md`). One `SKILL.md` per directory; no
   registry to update — discovery is automatic (confirmed: `wiki-sync`
   appeared in the live listing the turn after its directory was created).
2. **Draft the description first, alone.** One sentence. Test: covering the
   body, would a session deciding whether to load this skill understand
   what it's for? If the honest answer needs a second clause, that clause
   belongs in `## Applies to`.
3. **Write `## Applies to` right after the title**: triggers, explicit
   non-triggers (`ship`'s table is the pattern), example files, exceptions.
   Then decide on `when_to_use` (above): if the triggers include phrases
   the description doesn't carry, lift the short ones into it.
4. **Write the rest of the body** in whatever shape the task needs — `Why
   this exists` (dated, where there is one), `Steps`/`Procedure`, task-
   specific gotchas, `See also`. Cite real files and commands, not invented
   ones.
5. **Re-read the description against the finished body.** Bodies grow while
   writing; fix the description to stay accurate — undersold and
   overclaimed are both wrong.
6. **Check it against siblings.** Noticeably longer or more parenthetical
   than its neighbors means it hasn't had this treatment.

## A quick before/after

Bad — scope and triggers crammed into the sentence:

> Known traps in creating, renaming, or wiring a flake-parts module in this
> repo, including dirsAsCategory pitfalls, class validation gaps, and
> config shadowing (see below).

Good:

> How to create, rename, or wire a flake-parts module in this repo.

## See also

- Any existing `.agents/skills/*/SKILL.md` in this repo — read a couple
  before writing a new one; they're the worked examples, not this file's
  prose about them.
- `wiki-sync` skill — if the new skill's task touches something `wiki/`
  documents, that skill covers keeping the docs in sync as a separate step,
  not something to fold into this one.
