# How agents work in this repo

This chapter is for anyone who wants to know how coding agents are routed to
the right file, reminded of past mistakes and kept from letting docs go stale.
It covers `AGENTS.md`, rules files, skills, the lesson loop, doc upkeep and
helper scripts. A contributor who only edits modules can skip it. A human
using Claude Code in this checkout sees the hook messages described here.

Coding agents write and maintain most of this repo's docs, scripts, skills
and hooks, under the repo owner's direction. An agent has no memory of earlier sessions,
so these mechanisms route it to the right file and turn a mistake made once
into a reminder the next agent sees. Each mechanism is *automatic* (a [hook](glossary.md#hook-claude-code) or
check fires without anyone asking) or a *convention* (an instruction the agent
can skip). The [table at the end](#automatic-and-convention-side-by-side) says
which part is which.

## Where an agent starts

An agent starts at `AGENTS.md`, the cold-start file. `CLAUDE.md` is a symlink
to it, so a harness that looks for either name reads the same file.
`AGENTS.md` holds what applies to every session (hard rules, safety notes,
traps, the working loop) and points elsewhere for detail.

From there, `wiki/00-INDEX-for-agents.md` has a "By task" table that maps a
task ("land a change on `experimental`", "add a self-hosted service") to the
page and skill that answer it. Long wiki pages take one of two shapes:

- A *sibling pair*: `<page>.md` is narrative for a human reading cold, and
  `<page>-for-agents.md` covers the same ground at maximum density (paths,
  option names, commands, every trap as one line). An agent reads the
  sibling.
- A single page that opens with `## Quick facts`, used where the page is
  already compact or procedural.

Under Claude Code, the session-start hook
runs before the agent's first tool call. It adds the hostname, branch,
[worktree](glossary.md#worktree), dirty-path count, `core.hooksPath` and the
`just agent` helper names to the agent's context.

## Rules files load by path

A rules file under `.agents/rules/` holds detail that matters only under
particular paths. Its frontmatter has one key, `paths:`, a list of globs. For
example, `.agents/rules/flake-modules.md` lists `flake/modules/**` and
`flake/flake.nix`. Claude Code sees the directory as `.claude/rules` (a
symlink into `.agents/`) and loads a file only when the agent reads a file
matching its globs.

Other harnesses do not load rules files. For them `AGENTS.md` has a pointer
next to each trap, and the agent must open the file itself.

`check_docs.py rules` (part of `just wiki-lint`) checks that each rules file
has only the `paths:` key, that every glob matches at least one tracked file,
and that `AGENTS.md` names the file.

## Skills: procedures loaded on demand

A [skill](glossary.md#skill) is a markdown file at
`.agents/skills/<name>/SKILL.md` holding the full procedure for one kind of
task. An agent loads it when its description matches the task. Any agent can
read a skill as a plain file; Claude Code also lists the skills it finds
through `.claude/skills`, a symlink into `.agents/`, with no registry to
update.

| Part | Holds | Who sees it |
|---|---|---|
| `description` (frontmatter) | One sentence saying what the skill does, starting with a verb | Every harness's skill listing |
| `when_to_use` (frontmatter, optional) | Short trigger phrases, on one line | Claude Code only, appended to the description in its listing |
| `## Applies to` (first section) | The full trigger list: triggers, non-triggers, exceptions | Anyone who loaded the skill |

The listing shows only frontmatter, so the description has to be scannable.
Nothing may live only in `when_to_use`, because other harnesses ignore it.
`ship`'s `when_to_use` reads "A bare push, ship it, land this or merge this",
because a bare "push" is the phrase that caused the mistake the skill exists
to prevent.

The skill `new-skill` is the procedure for writing one. `check_docs.py
skill-files` enforces its mechanical half:

- a one-sentence description with no repo paths or parentheticals;
- `when_to_use` on one line;
- no frontmatter keys beyond `name`, `description` and `when_to_use`;
- no syntax that would let a skill run a command without a prompt;
- a `**Needs:** bash-guards` line under the title on any skill that runs a
  command the `Bash`-only guards cover (see below).

### The Needs tag

Many skills depend on [guard hooks](glossary.md#guard-hook) that match only
the harness's `Bash` tool. Rather than repeat that in each skill, the skill
carries one line between its title and `## Applies to`:

```md
**Needs:** bash-guards
```

It sits in the body because the checker rejects unknown frontmatter keys and
only the body loads with the skill. The vocabulary is `NEEDS_TAGS` in
`check_docs.py`, currently just `bash-guards`. The tag means that another
shell, or a tool other than `Bash`, runs the skill's commands without the git,
`just`, nix or sops checks, so an agent in that position warns the user
before it starts. The session-start hook prints the same reminder. The
checker fails a skill that runs `sops -d`, `nix eval`, `reset --hard` or the
deployed-secrets path without the tag, and the check has a test that it does.

## The lesson loop

A mistake an agent makes here becomes a numbered
[lesson](glossary.md#lesson) (a recorded mistake and its rule). The lesson's rule goes where an agent doing
that task already reads, and a hook delivers a reminder when the lesson
applies to particular paths or commands. The loop has four parts:

1. An article, `wiki/agent-lessons-learned/<N>-*.md`, gives the full
   account. Numbers are stable and cited across the repo, so they are never
   renumbered.
2. An index entry in `wiki/agent-lessons-learned.md`, filed under the moment
   it applies ("Before claiming a change works", "Before believing a tool, a
   check, or a count"), states the rule in one line. Each entry names its
   **Home** (the file that states the rule where an agent will be reading)
   and what **Enforced** it, or `none`.
3. The rule goes in its Home too. A lesson only the index states reaches
   nobody.
4. A topic in `.agents/lessons-map.toml` lists the paths (Claude Code
   `paths:` globs) or a command regex the lesson applies to, plus a one-line
   `remind`. The lesson-reminder hook puts that line into the agent's
   context before a matching edit or command, once per topic per session. An
   entry reminded this way says `none (reminded by …)` under Enforced, since
   a reminder is not a check.

`just agent lessons <path>` prints every topic a path falls under, with the
index lines of its lessons. With no argument it covers the files the current
branch changes. `check_docs.py lessons` fails on a lesson number with no entry
or article, an entry missing `Home:` or `Enforced:`, and a lessons map that has
drifted from the repo (a glob matching no tracked file, a missing skill or
rules file).

## Keeping docs current

A change that makes a wiki page stale fixes the page in the same change.

**Generated.** A table whose facts the repo already knows (the host table,
the category index tables) sits between
`<!-- generated:<name> … -->` and `<!-- /generated -->` markers. `just
wiki-gen` rewrites each region from its source, so an edit inside a region is
lost on the next run, except in a column the marker calls hand-written (such
as a host's role). To change a generated fact, change its source and run
`just wiki-gen`.

**Lint.**

- `just wiki-lint` runs `check_docs.py check`, static checks of the wiki,
  `AGENTS.md`, the rules files and the skills against the repo. The
  [checks chapter](agent-checks-and-guards.md#static-checks) lists them. The
  `generated` check is the same test as `just wiki-gen --check`.
- `check_docs.py siblings` fails when a `-for-agents.md` sibling's
  `_Last modified:_` date predates its source page's. The fix is to edit the
  sibling, then bump its date. When the source edit needs nothing in the
  sibling (a reorder, a typo), the agent adds a dated `_Sibling reviewed:
  <date> -- <reason>_` line instead. Bumping the date without reading the
  sibling is forbidden: it turns a caught omission into one nobody sees.
- The edit-check hook runs the sibling check on every wiki page an agent
  edits, before [preflight](glossary.md#preflight) would.
- `just agent book-lint` is the book's mechanical half: dead links and
  anchors, chapters missing from the summary, dates and counts that go stale.
  It runs in preflight.

**Skills for audits.**

- `wiki-sync`: the end-of-change procedure. Name what changed as facts, grep
  the wiki for them, fix each page and its sibling.
- `docs-audit-all`: a standalone whole-repo accuracy pass. It ranks docs with
  `just agent doc-drift`, splits them across parallel subagents with `just
  agent doc-partition`, and checks each claim against the code.
- `wiki-fact-check` and `book-fact-check`: read-only agents check a chosen set
  of docs, or the book, and report each claim as wrong, stale, unsupported,
  misleading or uncheckable. The orchestrator verifies the consequential
  findings and applies the corrections.
- `trim-docs`: tightens prose without breaking what lint pins in place
  (Contents blocks, date lines, siblings, anchors, lesson numbers).
- `fact-hygiene`: state only what was observed this session, qualify the rest
  in the same sentence, and replace a count, version or copied config value
  with a pointer to the file or command that answers it. `check_docs.py
  docrefs` flags the bare count-of-files shape.

## Recurring work becomes a script

A command pattern that agents keep re-typing becomes a script under
`.agents/scripts/`, run as `just agent <recipe>`. Bare `just agent` lists the
helpers, and the session-start hook names them at the start of each Claude
Code session. Examples:

- `show` reads several files or ranges in one call.
- `where` prints the branch, dirty paths and commits against
  `origin/experimental`.
- `commit` and `pr` carry the ship skill's commit and PR conventions.

The skill `agent-scripts` is the procedure. `just agent recurring` mines
agent command history for repeated shapes. It reads command fields only,
never output, and replaces literals with placeholders such as `<path>` and
`<str>`. The skill then asks whether a pattern carries a convention, such as
a fixed step order or a set of `--json` fields. Plain Unix pipelines stay
unscripted.

A new helper is a script in `.agents/scripts/`, in any language, plus a
one-line recipe in `.agents/scripts/agent.just`. The skill requires running
the helper on a case where it should find something, and committing it on its
own in the current branch. Scripts for humans go in `flake/scripts/`, where
Python buried inside a bash script is not allowed.

## When to propose a fix and when to make it

An agent that notices a problem outside its task proposes a fix and leaves the
problem alone, unless it is a small problem in a file it is already changing.

- `boyscouting`: small, local, behavior-neutral fixes (a stale comment, an
  unused variable) in a file the diff already touches go in the same commit,
  with a trailing clause saying so. A bug, a file the agent was not going to
  open, or a rename on taste is out of scope.
- `propose-issue`: for a defect found while doing something else. The agent
  re-checks it, runs `just threads "<keywords>"` to see whether it is already
  tracked, and asks the repo owner with a drafted title, body and label. Only on a yes
  does it run `gh issue create --repo NireBryce/nixos-configs`. The repo is
  hardcoded: an upstream bug is still tracked here, and filing elsewhere needs
  the repo owner to ask for that specific filing.

## Extraction candidates

When an agent writes or changes something whose mechanism would work outside
this repo, it records an extraction candidate instead of extracting it. The
test: restate the thing's purpose with every repo noun removed, and see
whether it is still true and useful.

`extract-agent-tooling` covers agent tooling (a skill, a lesson, a wiki
convention, a checker, a hook) and `extract-nix-tooling` covers Nix patterns.
Each records one file under `_loose-ends/extraction-candidates/agent-orchestration/`
or `_loose-ends/extraction-candidates/nix/`, in the same commit as the task
that surfaced it. The `-all` variants are standalone whole-repo sweeps that
also reconcile the existing candidate files. Copying anything into another
repo happens only when the repo owner asks.

## Automatic and convention, side by side

| Mechanism | Automatic part | Convention part |
|---|---|---|
| Cold start | Session-start hook (Claude Code) | Reading `AGENTS.md` and the agent index |
| Rules files | Loaded by path under Claude Code; `rules` lint | Opening them under other harnesses |
| Skills | Discovery, listing, `skill-files` lint | Loading the skill when it applies |
| Lessons | Lesson-reminder hook; `lessons` lint | Writing the article, entry, Home rule and map topic |
| Docs | `wiki-lint` (including its `generated` check) in preflight; edit-check hook | `wiki-sync`, `docs-audit-all`, `wiki-fact-check`, `book-fact-check`, `trim-docs`, `fact-hygiene` |
| Scripts | Helper names at session start | `agent-scripts`; checking `just agent` first |
| Proposals | None | `boyscouting`, `propose-issue` |
| Extraction | None | The `extract-*` skills |

## Sources

- `AGENTS.md`: header, hard rules, "State", "Before you start", "Working in
  this repo", "Docs"
- [00-INDEX-for-agents.md](../../wiki/00-INDEX-for-agents.md)
- [styleguide.md](../../wiki/meta/styleguide.md): "Two audiences per page",
  "Generated tables"
- [agent-lessons-learned.md](../../wiki/agent-lessons-learned.md)
- `.agents/lessons-map.toml`, `.agents/rules/flake-modules.md`,
  `.agents/rules/scripts.md`, `.agents/scripts/agent.just`
- `.agents/hooks/session-start.sh`, `.agents/hooks/lesson-reminder-pretooluse.py`,
  `.agents/hooks/edit-check-posttooluse.sh`
- `.agents/scripts/lessons.py`, `.agents/scripts/book_lint.py`
- `.agents/skills/`: `new-skill`, `ship`, `wiki-sync`, `docs-audit-all`,
  `wiki-fact-check`, `book-fact-check`, `trim-docs`, `fact-hygiene`,
  `agent-scripts`, `boyscouting`, `propose-issue`, `extract-agent-tooling`,
  `extract-nix-tooling`, `extract-agent-tooling-all`
- `wiki/meta/scripts/check_docs.py`, `wiki/meta/scripts/wiki_gen.py`
