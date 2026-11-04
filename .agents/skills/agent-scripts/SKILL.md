---
name: agent-scripts
description: Finds command patterns agents keep re-typing and turns them into scripts behind `just agent`.
when_to_use: Periodic sweep for recurring commands, or mid-task when you're assembling the same pipeline again or writing a command too long to read in a permission prompt.
---

# Agent scripts

**Needs:** bash-guards

## Applies to

Use this skill in an occasional sweep (the user asks, or a scheduled run), or
mid-task when you are hand-assembling the same pieces again or writing a
command too long to read in a permission prompt. Do not run it on every ship;
the patterns change over months. Scripts that humans run are out of scope:
they go in `flake/scripts/` under its conventions.

## Find candidates

`just agent recurring` reads this host's agent history for the repo (Claude
Code and other agent harnesses; the command field only, never output) plus
every other host's export from the private forge repo
`elly/agent-command-log`. Its header lists each source's session count and
marks an export older than 21 days STALE, meaning that host is not exporting.
A reader at 0 sessions after a harness upgrade means the history format
changed.

Exports carry shapes and hashed session ids only. Skill `ship` runs
`just agent recurring export` before each PR. On a new host, run
`just agent recurring setup` once; it needs a forge key
(`wiki/homelab/forgejo-for-agents.md`).

A shape replaces removed text with a category token: `<path>`, `<n>`, `<str>`
(quoted), `<var>`, `<url>`, `<word>`. `-u<val>` means a value was glued to the
flag. `<heredoc>`, `<loop>` and `<func>` mark dropped structure. After `just`,
a word survives only in recipe position, and only if the repo's recipe list
(just's `--summary`) contains it (`just agent show`, `just preflight`);
anything else becomes `<word>`. Every token is checked against a closed
vocabulary (see "Changing the miner"). Pass `--json` for tooling.

Each section gets its own verdict:

- **SEQUENCES**: producers run one after another (`&&`/`;`) in at least 3
  sessions. These are the script candidates. Each row is the longest run that
  holds its count; shorter overlapping rows are real sub-habits (for example
  `git branch -d -> git push --delete` alone, 43, versus the full post-merge
  cleanup starting at `git checkout`, 31).
- **BATCH READS**: sessions reading several things per call and printing
  headers between them. At 2026-09-29 this was 82% and 87% of 73 sessions,
  the commonest habit. Write one reader script (N files or ranges, a header
  each), not per-pair scripts.
- **PIPELINES**: filters per producer (`nix eval --raw | tail`,
  `grep -n | head`). These are plain Unix; leave them alone unless the filter
  is itself a convention (a `jq` filter, a fixed `--json` field set).
- **JUST**: sessions per recipe called. `just` calls are kept out of
  SEQUENCES and PIPELINES because they are already scripts; this section shows
  helper adoption. A helper still at 1-2 sessions weeks after it landed,
  while its SEQUENCES row keeps growing, is not being found. Name it where
  agents look (the SessionStart hook lists the helper names).

## Worked examples (2026-09-29)

- `show`: the BATCH READS habit as one reader over N specs.
- `preflight-brief`: replaces `just preflight | grep | tail`. It reads its
  steps from the preflight recipe so it cannot drift.
- `commit`, `ship-ready`, `ship-land` (`ship.py`): skill `ship`'s commit
  conventions (pathspec, stdin message, trailer, no trunk commits), its step-2
  preview and gate, and the post-merge cleanup (31 sessions), including the
  linked-worktree case.
- `pr` (`ship.py`, 2026-10-02): first left unscripted (`--body-file -` reads
  stdin), then wrapped once it carried conventions of its own: the disclosure
  line at both ends, `--base experimental`, and `push -u` first.
- `worktree new/prune` (`worktree.py`), `preflight-each`: skill
  `use-a-worktree`'s create step and its cleanup (which was never done), and
  ship's each-commit-green loop (which left worktrees behind when a check
  failed). 2026-10-03: `preflight-brief` runs steps concurrently and
  `preflight-each` caches `just check` per `flake/` tree. For a larger range
  (several commits), `preflight-each --jobs N` runs N commits at once,
  clamped by `MemAvailable`; the budget is in its header. Use it when memory
  allows.
- `where [<pr>]` (`where.py`, 2026-10-03): orientation, the largest
  unscripted habit left: `git fetch -> git status -sb` (53 sessions),
  `git log --oneline <range> -> git diff --stat <range>` (50),
  `git log --oneline -N <-> git status -sb` (47), `gh pr view <n> --json
  -> log -> diff --stat` (30). It fetches (offline is tolerated) and prints
  the status line, dirty paths, and commits and diff stat against
  `origin/experimental`, plus the PR. Read-only.

Adoption (2026-11-04; exports from nire-cube, nire-durandal and nire-tenacity,
216 Claude Code and zcode sessions): `preflight` 95, `wiki-lint` 89,
`agent pr`, `agent ship-ready` and `agent ship-land` 49 each, `agent
preflight-brief` 47, `agent worktree` 37, `agent commit` 33, `agent where` 24,
`agent preflight-each` 11. Batch reads by hand still occur in 188 sessions
(87%), against 86% on 2026-10-03, so the helpers have not displaced them. Many
of the recent sessions are the ones that wrote these helpers, which inflates
their counts.

## Is it worth a script?

Write a script when the pattern carries a **convention**: a header format, a
set of `nix eval`/`gh --json` flags, a fixed step order (fetch, then status).
Do not script plain Unix; a script hides what the user would learn from
reading the command.

Check `just agent` and the root `just` list first, and **extend** an
overlapping recipe instead of starting a second one. Committing, ship's
preview/gate and the post-merge cleanup belong to `ship.py`; branches merged
elsewhere belong to `just branches prune`.

## Extract it

1. Put the script in `.agents/scripts/`, executable, any language.
   Generalize past the cases seen (N files, not two). The header says what
   question it answers and which SEQUENCES row or habit it replaces. If it
   needs a toolchain not already on the hosts (python3 and bash are; the
   flake's only devShell is `flake/modules/dev-shell.nix`), ask the user
   before adding a package to it.
2. Add a one-line recipe in `.agents/scripts/agent.just`: a summary comment,
   then `@"{{scripts}}/<script>" "$@"` (positional arguments are on, so
   quoted arguments stay whole). Module recipes run from `.agents/scripts/`,
   not the caller's directory, so a script that takes paths starts with
   `cd "{{invocation_directory()}}" &&` (`show` does). `{{repo}}` is the
   root.
3. Run it on a real case, and on one where it should find something, and
   check that it does. A script that reports success has not been tested
   (§1). Then commit it **on its own** in the current branch/PR as
   `feat(agent-scripts): <name>`. Do not open a separate PR.
4. Skill `wiki-sync` covers naming it on its topic's wiki page. If a skill
   spells out the steps the script replaces (ship's preview, the cleanup),
   point that skill at the script.

## Changing the miner

The shape step in `recurring.py` is a privacy boundary: no literal text may
survive into a shape. It works from allowlists (commands on PATH, per-tool
`SUBCOMMANDS`, `WRAPPERS`, `FIND_OPTS`). To widen any of them, add a hostile
case to `LEAKS` in `test_recurring.py` (it runs in `just preflight` and CI
and checks every shape token against the closed vocabulary). `LEAKS` holds
what leaked before: grep-pattern pieces as fake commands (`git.moose"`),
value-glued flags (`-uadmin`), loop variables (`for host in`), wrapper options
(`sudo -u host`), prose from quoted `--body "..."` text, and `<<\EOF` heredoc
bodies. Known residual (documented in the docstring): an unquoted 1-3 letter
word after `-`, and unquoted `--long-flag` names.

The `just` recipe vocabulary is read at run time (`just_recipes()`; tests pin
it). Recipe names are repo-defined and public. A non-recipe word after `just`
stays `<word>`, and `test_recurring.py` has cases for that.

**Bump `FORMAT` whenever shaping gets stricter** or the export's shape
changes (3: recipe names and the `just` kind). Exports merge, so keys written
under looser rules would otherwise persist. Files of another format are
skipped on read and rebuilt on that host's next export.

Never commit transcript lines or raw commands. This repo is public, and they
carry hostnames, ports, and paths. The export is the only thing that leaves a
host, and `test_recurring.py`'s `Export` case checks it against the same
vocabulary. Commands whose quoting shlex cannot follow (escaped or nested
quotes) are dropped whole, about 4% at 2026-09-29; before that, prose in
`gh ... --body "..."` leaked as commands.
