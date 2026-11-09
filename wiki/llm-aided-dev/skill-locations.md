# Where skills live, and how an agent loads one

_Last modified: 2026-11-08_

Skills are written once under `.agents/skills/` and reached from Claude Code
through the symlink `.claude/skills`. This page records what Claude Code's
documentation says about skill locations and symlinks, what this repo does
beyond that, and why an agent should load a skill with the `Skill` tool
instead of reading its `SKILL.md`. Documentation checked 2026-11-08 against
[Extend Claude with skills](https://code.claude.com/docs/en/skills).

## Contents

- [Layout in this repo](#layout-in-this-repo)
- [What Claude Code's documentation says](#what-claude-codes-documentation-says)
- [Loading a skill: the `Skill` tool, not a file read](#loading-a-skill-the-skill-tool-not-a-file-read)
- [Traps](#traps)

## Layout in this repo

- `.agents/skills/<name>/SKILL.md` is the real file, in a location that is
  not specific to Claude Code.
- `.claude/skills` is a symlink to `../.agents/skills`, so
  `.claude/skills/<name>/SKILL.md` and `.agents/skills/<name>/SKILL.md` are
  one file with two spellings. `.claude/rules` and `.claude/settings.json`
  are symlinks into `.agents/` the same way.
- Edit through `.agents/skills/`. A tool that follows the `.claude` path
  edits the same file.

## What Claude Code's documentation says

The docs state:

- Project skills are discovered at `.claude/skills/<name>/SKILL.md`,
  personal ones at `~/.claude/skills/<name>/SKILL.md`. In a monorepo the
  project path is searched from the start directory up to the repository
  root.
- A skill folder entry (`<name>`) in a skills directory can be a symlink to
  a directory elsewhere. Claude Code reads `SKILL.md` from the target and
  loads the skill once, even when several paths point at the same target.
  Plugin skills handle symlinks differently.
- Claude can load a skill itself when it is relevant, or the user can type
  `/skill-name`. Denying the `Skill` tool in `/permissions` disables all
  skills, and `Skill(name)` rules allow or deny one.
- Claude Code watches the skills directories: adding, editing or removing a
  skill is picked up in the session. A skills directory that did not exist
  when the session started needs `/reload-skills`. Change detection covers
  `SKILL.md` text only.

The docs do not state:

- `.agents/skills`, or `AGENTS.md`. Neither appears on the page. Claude Code
  does not read `.agents/skills`; it finds the skills only through
  `.claude/skills`.
- A symlink on the skills directory itself. The documented case is a
  symlink per skill folder. This repo symlinks the whole directory, and
  Claude Code lists and loads the skills through it (observed 2026-11-08).
  If a Claude Code release stops following it, the symptom is an empty skill
  list; the fix is one symlink per skill folder under a real
  `.claude/skills/` directory.
- How a relative link in `SKILL.md` is resolved. The docs define
  `${CLAUDE_SKILL_DIR}` for commands, and show relative links to supporting
  files without saying what they resolve against.

## Loading a skill: the `Skill` tool, not a file read

In Claude Code, load a named skill with the `Skill` tool. The tool call:

- puts the skill's text into the conversation as an instruction to follow;
- reports a base directory for the skill, observed 2026-11-08 as
  `/home/elly/nixos/.claude/skills/<name>` (the `.claude` spelling), which
  is what the skill's relative links such as `side-flows.md` resolve
  against;
- goes through the harness's skill handling and permission rules, which a
  `Read` of the file does not.

A `Read` of `.agents/skills/<name>/SKILL.md` returns the same text, and
following it works. It skips the three points above. Read the file when the
task is to inspect or edit the skill, or in a harness with no skill-loading
tool.

## Traps

- **Same file, two paths.** A path printed by the `Skill` tool starts with
  `.claude/skills/`; the repo's own links and `AGENTS.md` use
  `.agents/skills/`. Do not conclude from the different prefix that the
  files differ.
- **Recursive search does not follow the symlink by default.** `grep -r`
  and `rg` over `.claude` find nothing in `.claude/skills` (checked
  2026-11-08); `rg --follow` and `grep -R` do follow it. Search
  `.agents/skills/` to find skill text.
- **A skill added mid-session** appears without a restart only when
  `.claude/skills` already existed at session start.
- **`.claude/` must be a real directory.** It holds symlinks into
  `.agents/`; replacing it with a symlink breaks Agent-tool worktree
  isolation (skill `use-a-worktree`).
