---
name: new-skill
description: Writes a new SKILL.md, or fixes the frontmatter of an existing skill.
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
skill. A description stuffed with scope caveats is hard to scan there;
`when_to_use` is where the phrases that should fire it go, kept apart so
the description stays a statement of purpose. Other harnesses
ignore `when_to_use`, so nothing may live *only* there —
`## Applies to` stays the complete trigger list. The body loads in full
once the skill fires, so detail there costs nothing.

Add `when_to_use` where a missed trigger has cost something
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

Write the description as a plain statement of what the skill does, starting
with a verb ("Adds a package to...", "Checks whether..."). Skip "How to..."
and "Known traps in..." openers: the first is filler, the second reads as
scope, not purpose. Put when it fires in `when_to_use`, in direct words
(the user asked for this on 2026-10-27, replacing the earlier "How to"
preference; "Known traps in..." was rejected on 2026-08-22).

## The `**Needs:**` tag

A skill whose commands are covered by guard hooks says so with one line
between the H1 and `## Applies to`, instead of a sentence of its own:

```md
# Landing work on experimental in nixos-configs

**Needs:** bash-guards
```

`bash-guards` means the commands here (git, `just`, nix, sops) are checked
by hooks that match only the harness's `Bash` tool in Claude Code and
ZCode; another harness, shell or tool runs them unchecked. An agent in that
position warns the user before starting and checks commands by hand
(skill `guards-without-hooks`). The tag goes in the body, not the frontmatter: the skill-files
check rejects unknown frontmatter keys, and the body is what loads with the
skill. The check also fails a skill that mentions one of the guarded commands
without the tag (the guard-command cue in factcheck.toml's `[skill-files]` lists them, and
this paragraph avoids naming them so it does not trip it). A new tag is a
deliberate edit to `needs-tags` in factcheck.toml and a line here.

## Frontmatter this repo doesn't use

Only `name`, `description`, and `when_to_use` (the skill-files check
rejects any other key). In particular, no `allowed-tools` and no dynamic
context injection (an exclamation mark followed by a backticked command, or
a fence opened with three backticks and an exclamation mark): both let a
skill run commands without a prompt, and the hooks can't see an injected
command. The skill-files check flags injection syntax anywhere in a
SKILL.md, so in prose never put an exclamation mark directly before a
backtick.

## Steps

1. **Pick a name**: kebab-case, matching the directory exactly
   (`.agents/skills/<name>/SKILL.md`). One `SKILL.md` per directory; no
   registry to update — discovery is automatic (confirmed: `wiki-sync`
   appeared in the live listing the turn after its directory was created).
2. **Draft the description first, alone.** One sentence. Test: covering the
   body, would a session deciding whether to load this skill understand
   what it's for? If it needs a second clause, that clause
   belongs in `## Applies to`.
3. **Write `## Applies to` right after the title** (and the `**Needs:**` line
   above it, when the skill needs one): triggers, explicit
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

> Creates, renames and wires a module in the flake modules tree.

## See also

- Any existing `.agents/skills/*/SKILL.md` in this repo — read a couple
  before writing a new one; they're the worked examples, not this file's
  prose about them.
- `wiki-sync` skill — if the new skill's task touches something `wiki/`
  documents, that skill covers keeping the docs in sync as a separate step,
  not something to fold into this one.
