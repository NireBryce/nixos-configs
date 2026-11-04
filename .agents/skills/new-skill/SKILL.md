---
name: new-skill
description: Writes a new SKILL.md, or fixes the frontmatter of an existing skill.
when_to_use: Creating a SKILL.md, or editing any skill's description or when_to_use.
---

# Writing a new skill

## Applies to

Use this skill when creating a new `.agents/skills/<name>/SKILL.md`, or when
editing an existing skill's frontmatter `description` or `when_to_use`. Do not
use it for body-only edits.

## The rule

Each of three places has one job:

| Where | Holds | Who sees it |
|---|---|---|
| `description` | **One sentence: what the skill does or is for.** No file paths, no parenthetical scope lists, no trigger conditions. | Every harness's skill listing |
| `when_to_use` (optional) | Short trigger phrases a user or task would say, on one line, comma-separated or as a short sentence. | Claude Code only: appended to `description` in its listing |
| `## Applies to` (right after the H1) | The full trigger detail: triggers, non-triggers, exceptions, examples. | Anyone who loaded the skill |

A session deciding whether to load a skill sees only the frontmatter in the
live skill listing. A description full of scope caveats is hard to scan
there, so the trigger phrases go in `when_to_use` and the description stays a
statement of purpose. Other harnesses ignore `when_to_use`, so nothing may
live only there; `## Applies to` is the complete trigger list. The body loads
in full once the skill fires, so detail there costs nothing.

Add `when_to_use` where a missed trigger has cost something (`ship`'s bare
"push", `secrets-hygiene`'s `sops` commands) or where `## Applies to` names
concrete phrases the description lacks. Skip it when the description already
says everything. Derive the phrases from `## Applies to` and AGENTS.md; do not
widen scope. Claude Code truncates description plus `when_to_use` at 1,536
characters combined (code.claude.com/docs/en/skills, checked 2026-10-01).

Both values must be plain YAML scalars. Never open with a quote:
`"push", "ship it"` parses as a quoted string plus junk, so lead with a word,
for example `A bare "push", ...`. Do not use `: ` or ` #` inside.

`just wiki-lint`'s `skill-files` check enforces the mechanical half of this
rule, so frontmatter that drifts fails the run:

- `description`: one sentence, no repo paths, no parentheticals (wordiness is
  a REVIEW finding only).
- `when_to_use`: one line, no repo paths, under the combined cap (over 40
  words is REVIEW).
- Both are plain YAML scalars.
- No frontmatter keys beyond `name`, `description` and `when_to_use` (every
  harness silently ignores a misspelt `when-to-use`).

Write the description as a plain statement of what the skill does, starting
with a verb ("Adds a package to...", "Checks whether..."). Do not open with
"How to..." (filler) or "Known traps in..." (reads as scope, not purpose).
Put when the skill fires in `when_to_use`, in direct words. The user asked for
this on 2026-10-27, replacing the earlier "How to" preference; "Known traps
in..." was rejected on 2026-08-22.

## The `**Needs:**` tag

A skill whose commands are covered by guard hooks says so with one line
between the H1 and `## Applies to`, instead of a sentence of its own:

```md
# Landing work on experimental in nixos-configs

**Needs:** bash-guards
```

`bash-guards` means the commands in the skill (git, `just`, nix, sops) are
checked by hooks that match only the harness's `Bash` tool in Claude Code and
ZCode. Another harness, shell or tool runs them unchecked. An agent in that
position warns the user before starting and checks commands by hand (skill
`guards-without-hooks`).

The tag goes in the body, not the frontmatter: the skill-files check rejects
unknown frontmatter keys, and the body is what loads with the skill. The check
also fails a skill that mentions one of the guarded commands without the tag
(the guard-command cue in factcheck.toml's `[skill-files]` lists them; this
paragraph avoids naming them so it does not trip the cue). To add a new tag,
edit `needs-tags` in factcheck.toml and add a line here.

## Frontmatter this repo doesn't use

Only `name`, `description`, and `when_to_use` are allowed (the skill-files
check rejects any other key). In particular, do not use `allowed-tools` or
dynamic context injection (an exclamation mark followed by a backticked
command, or a fence opened with three backticks and an exclamation mark). Both
let a skill run commands without a prompt, and the hooks cannot see an
injected command. The skill-files check flags injection syntax anywhere in a
SKILL.md, so in prose never put an exclamation mark directly before a
backtick.

## Steps

1. **Pick a name**: kebab-case, matching the directory exactly
   (`.agents/skills/<name>/SKILL.md`). Use one `SKILL.md` per directory.
   There is no registry to update; discovery is automatic (`wiki-sync`
   appeared in the live listing the turn after its directory was created).
2. **Draft the description first, alone.** Write one sentence. Test it:
   cover the body and ask whether a session deciding to load this skill would
   understand what it is for. A second clause belongs in `## Applies to`.
3. **Write `## Applies to` right after the title** (and the `**Needs:**` line
   above it, when the skill needs one): triggers, explicit non-triggers
   (`ship`'s table is the pattern), example files, exceptions. Then decide on
   `when_to_use` (above): if the triggers include phrases the description does
   not carry, lift the short ones into it.
4. **Write the rest of the body** in whatever shape the task needs: `Why this
   exists` (dated, where there is one), `Steps`/`Procedure`, task-specific
   gotchas, `See also`. Cite real files and commands.
5. **Re-read the description against the finished body.** Bodies grow while
   you write; correct the description so it neither undersells nor overclaims.
6. **Compare it with sibling skills.** If it is noticeably longer or more
   parenthetical than its neighbors, it needs the same trimming.

## A quick before/after

Bad (scope and triggers crammed into the sentence):

> Known traps in creating, renaming, or wiring a flake-parts module in this
> repo, including dirsAsCategory pitfalls, class validation gaps, and
> config shadowing (see below).

Good:

> Creates, renames and wires a module in the flake modules tree.

## See also

- Any existing `.agents/skills/*/SKILL.md`: read a couple before writing a
  new one. They are the worked examples.
- `wiki-sync` skill: if the new skill's task touches something `wiki/`
  documents, that skill covers keeping the docs in sync as a separate step.
