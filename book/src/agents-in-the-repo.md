# How agents work in this repo

Coding agents write and maintain most of this repo's docs, scripts, skills
and hooks, under the user's direction. This chapter shows how an agent with
no memory of earlier sessions finds the right file for a task, and how a
mistake made once turns into a reminder the next agent sees. For each
mechanism it says whether it is *automatic* (a hook or check fires without
anyone asking) or a *convention* (an instruction the agent is told to follow
and can skip).

## Where an agent starts

An agent starts at `AGENTS.md`, the cold-start file, and is routed from there
by task. `CLAUDE.md` is a symlink to `AGENTS.md`, so a harness that looks
for either name reads the same file. `AGENTS.md` holds what applies to every
session: the hard rules, the safety notes, the traps, the working loop. It
points elsewhere for detail.

From `AGENTS.md`, an agent goes to `wiki/00-INDEX-for-agents.md`, whose "By
task" table maps a task ("land a change on `experimental`", "add a
self-hosted service") to the page and the skill that answer it. Long wiki
pages come in one of two agent-facing shapes:

- A *sibling pair*: `<page>.md` is narrative for a human reading cold, and
  `<page>-for-agents.md` covers the same ground at maximum density (paths,
  option names, commands, every trap as one line). An agent reads the
  sibling.
- A single page that opens with `## Quick facts`: used where the page is
  already compact or procedural, so a sibling would only restate it.

Under Claude Code, the session-start [hook](glossary.md#hook-claude-code)
(a command the harness runs at a fixed event) adds the hostname, branch,
[worktree](glossary.md#worktree), dirty-path count, `core.hooksPath` and the `just agent` helper
names to the agent's context before its first tool call.

Automatic: the session-start hook. Convention: reading `AGENTS.md` and the
index, and choosing the sibling over the human page.

Source: `AGENTS.md`, header and "Docs";
[00-INDEX-for-agents.md](../../wiki/00-INDEX-for-agents.md);
[styleguide.md](../../wiki/meta/styleguide.md), "Two audiences per page";
`.agents/hooks/session-start.sh`.

## Rules files load by path

A rules file under `.agents/rules/` holds detail that matters only when
working under particular paths, and Claude Code loads it only when a file
matching those paths is read. Each rules file opens with frontmatter whose
only key is `paths:`, a list of globs. For example,
`.agents/rules/flake-modules.md` lists `flake/modules/**` and
`flake/flake.nix`. Claude Code sees the directory as `.claude/rules`, a
symlink into `.agents/`.

Other harnesses do not load rules files. For them `AGENTS.md` has a pointer
next to each trap ("open it before working under its paths"), so the agent
must open the file itself.

`check_wiki.py rules` (part of `just wiki-lint`) checks that each rules file
has only the `paths:` key, that every glob matches at least one tracked file,
and that `AGENTS.md` names the file.

Automatic: loading under Claude Code, and the lint check. Convention: opening
the file under any other harness.

Source: `AGENTS.md`, header; `.agents/rules/flake-modules.md` frontmatter;
`wiki/meta/scripts/check_wiki.py`, docstring for `rules`.

## Skills: procedures loaded on demand

A [skill](glossary.md#skill) is a markdown file at
`.agents/skills/<name>/SKILL.md` that holds the full procedure for one kind
of task, and an agent loads it when its description matches the task in
hand. Any agent can read a skill as a plain file. Claude Code also lists the
skills it finds through `.claude/skills`, a symlink into `.agents/`, with no
registry to update.

A skill's text has three parts, each with one job:

| Part | Holds | Who sees it |
|---|---|---|
| `description` (frontmatter) | One sentence saying what the skill does, starting with a verb | Every harness's skill listing |
| `when_to_use` (frontmatter, optional) | Short trigger phrases, on one line | Claude Code only, appended to the description in its listing |
| `## Applies to` (first section) | The full trigger list: triggers, non-triggers, exceptions | Anyone who loaded the skill |

A skill triggers when the agent reads the listing and decides the
description fits its task. The listing shows only frontmatter, so the
description has to be scannable. Nothing may live only in `when_to_use`,
because other harnesses ignore it. For example, `ship`'s `when_to_use` reads
"A bare push, ship it, land this or merge this", which is the phrase that
caused the mistake the skill exists to prevent.

The skill `new-skill` is the procedure for writing one. `check_wiki.py
skill-files` enforces the mechanical half of that procedure: one-sentence
description with no repo paths or parentheticals, `when_to_use` on one line,
no frontmatter keys beyond `name`, `description` and `when_to_use`. It also
rejects syntax that would let a skill run a command without a prompt.

Automatic: discovery and listing, and the frontmatter lint. Convention:
loading the skill when it applies.

Source: `.agents/skills/new-skill/SKILL.md`, "The rule", "Frontmatter this
repo doesn't use" and "Steps"; `.agents/skills/ship/SKILL.md` frontmatter;
`AGENTS.md`, header; `wiki/meta/scripts/check_wiki.py`, docstring for
`skill-files`.

## The lesson loop

A mistake an agent makes here becomes a numbered
[lesson](glossary.md#lesson), a rule in the place an agent doing that task
already reads, and, where it applies to particular paths or commands, a
reminder that a hook delivers at that moment. The loop has four parts:

1. An article, `wiki/agent-lessons-learned/<N>-*.md`, gives the full
   account. Numbers are stable and cited across the repo, so they are never
   renumbered.
2. An index entry in `wiki/agent-lessons-learned.md`, filed under the moment
   it applies ("Before claiming a change works", "Before believing a tool, a
   check, or a count"), states the rule in one line. Each entry names its
   **Home** (the file that states the rule where an agent will be reading)
   and what **Enforced** it, or `none`.
3. The rule goes in its Home too. The index says why: a lesson only the
   index states reaches nobody.
4. A topic in `.agents/lessons-map.toml` lists the paths (Claude Code
   `paths:` globs) or a command regex the lesson applies to, plus a one-line
   `remind`. The lesson-reminder hook puts that line into the agent's
   context before a matching edit or command, once per topic per session.

`just agent lessons <path>` prints every topic a path falls under, with the
index lines of its lessons. With no argument it covers the files the current
branch changes. `check_wiki.py lessons` fails on a § number with no entry or
no article, an entry missing `Home:` or `Enforced:`, and a map that has
drifted from the repo (a glob matching no tracked file, a missing skill or
rules file).

The index treats a reminder as different from a check: an entry reminded by
the hook says `none (reminded by …)` under Enforced.

Automatic: the reminder hook and the lint check. Convention: writing the
article, the entry, the Home rule and the map topic.

Source: [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md),
header; `.agents/lessons-map.toml`, header;
`.agents/hooks/lesson-reminder-pretooluse.py`, docstring;
`.agents/scripts/lessons.py`, docstring; `wiki/meta/scripts/check_wiki.py`,
docstring for `lessons`.

## Keeping docs current

A change that makes a wiki page stale fixes the page in the same change, and
several mechanisms back that rule. They split into generators, checks that
fire on their own, and skills an agent runs.

- **Generated regions.** A table whose facts the repo already knows (the
  host table, the category index tables, the module counts) sits between
  `<!-- generated:<name> … -->` and `<!-- /generated -->` markers.
  `just wiki-gen` rewrites each region from its source; an edit inside a
  region is lost on the next run. To change a generated fact, change its
  source and run `just wiki-gen`.
- **`just wiki-lint`** runs `wiki/meta/scripts/check_wiki.py check`, a set of
  static checks of the wiki, `AGENTS.md`, the rules files and the skills
  against the repo. The [checks chapter](agent-checks-and-guards.md) lists
  what class of drift each catches.
- **The sibling-date rule.** `check_wiki.py siblings` fails when a
  `-for-agents.md` sibling's `_Last modified:_` date predates its source
  page's. The fix is to edit the sibling, then bump its date. When the source
  edit needs nothing in the sibling (a reorder, a typo), the agent adds a
  dated `_Sibling reviewed: <date> -- <reason>_` line to the sibling instead.
  Bumping the sibling's date without reading it is forbidden, because that
  turns a caught omission into a silent one.
- **The edit-check hook** runs the sibling check on every wiki page an agent
  edits and reports a stale pair at once, before [preflight](glossary.md#preflight)
  would.
- **Skill `wiki-sync`** is the procedure an agent runs at the end of a change:
  name what changed as facts, grep the wiki for them, fix each page and its
  sibling.
- **Skill `docs-audit-all`** is a standalone whole-repo accuracy pass. It
  ranks docs with `just agent doc-drift`, splits them across parallel
  subagents with `just agent doc-partition`, and checks each claim against
  the code. Its own text says a lint-clean wiki is not an accurate one.
- **Skill `trim-docs`** tightens prose without breaking what lint pins in
  place (Contents blocks, date lines, siblings, anchors, § numbers).
- **Skill `fact-hygiene`** governs how a fact is written so it does not rot:
  state only what was observed this session, qualify the rest in the same
  sentence, and replace a count, version or copied config value with a
  pointer to the file or command that answers it. `check_wiki.py docrefs`
  flags the bare count-of-files shape.

Automatic: `just wiki-gen --check` and `just wiki-lint` inside preflight and
CI, and the edit-check hook. Convention: running `just wiki-gen`, and the
skills.

Source: `AGENTS.md`, hard rules, "State" and "Docs";
[styleguide.md](../../wiki/meta/styleguide.md), "Two audiences per page" and
"Generated tables"; `wiki/meta/scripts/wiki_gen.py`, docstring;
`.agents/hooks/edit-check-posttooluse.sh`; `.agents/skills/wiki-sync/SKILL.md`;
`.agents/skills/docs-audit-all/SKILL.md`; `.agents/skills/trim-docs/SKILL.md`;
`.agents/skills/fact-hygiene/SKILL.md`.

## Recurring work becomes a script

A command pattern that agents keep re-typing becomes a script under
`.agents/scripts/`, run as `just agent <recipe>`. Bare `just agent` lists the
helpers, and the session-start hook names them at the start of each Claude
Code session. Examples of helpers: `show` reads several files or ranges in
one call, `where` prints the branch, dirty paths and commits against
`origin/experimental`, and `commit` and `pr` carry the ship skill's commit and
PR conventions.

The skill `agent-scripts` is the procedure. `just agent recurring` mines
agent command history for repeated shapes (command fields only, never
output, with literals replaced by placeholders such as `<path>` and
`<str>`). The skill then asks whether a pattern carries a convention (a fixed
step order, a set of `--json` fields); plain Unix pipelines stay unscripted.
A new helper is a script in `.agents/scripts/`, in any language, plus a
one-line recipe in `.agents/scripts/agent.just`. The skill requires running
the helper on a case where it should find something, and committing it on its
own in the current branch.

Scripts in `.agents/scripts/` may be in any language. Scripts for humans go
in `flake/scripts/`, where Python buried inside a bash script is not allowed.

Automatic: the session-start hook's list of helper names. Convention:
checking `just agent` before hand-building a pipeline, and the extraction
procedure.

Source: `.agents/skills/agent-scripts/SKILL.md`; `.agents/scripts/agent.just`;
`.agents/rules/scripts.md`; `AGENTS.md`, "Before you start";
`.agents/hooks/session-start.sh`.

## Proposing a fix instead of making it

An agent that notices a problem outside its task proposes it rather than
fixing it, unless the problem is small and in a file it is already
changing. These skills draw the line:

- **`boyscouting`** covers small, local, behavior-neutral fixes (a stale
  comment, an unused variable) in a file the diff already touches. The fix
  goes in the same commit, with a trailing clause in the message saying it
  is incidental. A real bug, a file the agent was not going to open, or a
  rename on taste is out of scope.
- **`propose-issue`** covers a real defect found while doing something else.
  The agent re-checks it, runs `just threads "<keywords>"` to see whether it
  is already tracked, and asks the user with a drafted title, body and
  label. Only on a yes does it run `gh issue create --repo
  NireBryce/nixos-configs`. The repo is hardcoded: an upstream bug is still
  tracked here, and filing on another project needs the user to ask for that
  specific filing.

Both are conventions; no hook enforces them.

Source: `.agents/skills/boyscouting/SKILL.md`;
`.agents/skills/propose-issue/SKILL.md`; `AGENTS.md`, "Working in this repo".

## Extraction candidates

When an agent writes or changes something whose mechanism would work outside
this repo, it records an extraction candidate rather than extracting it. The
skill `extract-agent-tooling` covers agent tooling (a skill, a lesson, a
wiki convention, a checker, a hook); `extract-nix-tooling` covers Nix
patterns. Each records one file under
`_loose-ends/extraction-candidates/agent-orchestration/` or
`_loose-ends/extraction-candidates/nix/`, in the same commit as the task
that surfaced it. The test is to restate the thing's purpose with every repo
noun removed and see whether it is still true and useful. The `-all` variants
(`extract-agent-tooling-all`, `extract-nix-tooling-all`) are deliberate
whole-repo sweeps that also reconcile the existing candidate files. Copying
anything into another repo happens only when the user asks.

All four are conventions.

Source: `.agents/skills/extract-agent-tooling/SKILL.md`;
`.agents/skills/extract-nix-tooling/SKILL.md`;
`.agents/skills/extract-agent-tooling-all/SKILL.md`.

## Automatic and convention, side by side

| Mechanism | Automatic part | Convention part |
|---|---|---|
| Cold start | Session-start hook (Claude Code) | Reading `AGENTS.md` and the agent index |
| Rules files | Loaded by path under Claude Code; `rules` lint | Opening them under other harnesses |
| Skills | Discovery, listing, `skill-files` lint | Loading the skill when it applies |
| Lessons | Lesson-reminder hook; `lessons` lint | Writing the article, entry, Home rule and map topic |
| Docs | `wiki-lint` and `wiki-gen --check` in preflight; edit-check hook | `wiki-sync`, `docs-audit-all`, `trim-docs`, `fact-hygiene` |
| Scripts | Helper names at session start | `agent-scripts`; checking `just agent` first |
| Proposals | None | `boyscouting`, `propose-issue` |
| Extraction | None | The `extract-*` skills |

Source: the sections above.
