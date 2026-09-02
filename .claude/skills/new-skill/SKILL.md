---
name: new-skill
description: How to write a new SKILL.md in this repo, keeping its frontmatter description concise and accurate and its scope details elsewhere.
---

# Writing a new skill

## Applies to

Creating a new `.claude/skills/<name>/SKILL.md` in this repo, or editing an
existing one's frontmatter `description`. Not for editing a skill's body
content alone — only touch this when the description needs to change too.

## The rule

Frontmatter `description` is **one sentence: what the skill does or is
for.** No file paths, no parenthetical scope lists, no trigger conditions —
all of that goes in `## Applies to`, the section right after the H1.

This isn't just tone: the live skill listing a session sees shows only
`name: description`, and that's the only information available when
deciding whether to load a skill. Scope caveats there read as noise. The
body, by contrast, loads in full once the skill fires — trigger detail in
`## Applies to` costs nothing there.

Prefer active "How to `<verb>`…" phrasing for a procedural skill over a
"Known traps in…" noun phrase — "traps" reads as scope, not purpose (Elly
rejected the latter for `new-flake-module` on 2026-08-22; the accepted form
is that skill's current description). A short flow description without
literal "How to" wording is fine (`ship`'s) as long as it states purpose.

## Steps

1. **Pick a name**: kebab-case, matching the directory exactly
   (`.claude/skills/<name>/SKILL.md`). One `SKILL.md` per directory; no
   registry to update — discovery is automatic (confirmed: `wiki-sync`
   appeared in the live listing the turn after its directory was created).
2. **Draft the description first, alone.** One sentence. Test: covering the
   body, would a session deciding whether to load this skill understand
   what it's for? If the honest answer needs a second clause, that clause
   belongs in `## Applies to`.
3. **Write `## Applies to` right after the title**: triggers, explicit
   non-triggers (`ship`'s table is the pattern), example files, exceptions.
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

- Any existing `.claude/skills/*/SKILL.md` in this repo — read a couple
  before writing a new one; they're the worked examples, not this file's
  prose about them.
- `wiki-sync` skill — if the new skill's task touches something `wiki/`
  documents, that skill covers keeping the docs in sync as a separate step,
  not something to fold into this one.
