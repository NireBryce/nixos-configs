---
name: agent-scripts
description: How to find the command patterns agents keep re-typing and extract them into general scripts behind `just agent`.
---

# Agent scripts

## Applies to

An occasional sweep (the user asks, or a scheduled run), or mid-task when
you catch yourself hand-assembling the same pieces again, or writing a
command too long to read in a permission prompt. Not every ship:
the patterns move over months. Not for scripts humans run: those go in
`flake/scripts/` under its conventions.

## Find candidates

`just agent recurring` reads this host's agent history for the repo --
Claude Code, OpenCode, and zcode, command field only, never output -- plus
every other host's export from the private forge repo
`elly/agent-command-log`. Its header lists each source's session count (a
reader at 0 after a harness upgrade is a format change, not quiet) and
marks an export older than 21 days STALE: that host isn't exporting.
Exports carry shapes and hashed session ids only; skill `ship` runs
`just agent recurring export` before each PR. New host: `just agent
recurring setup` once (needs a forge key, `wiki/homelab/forgejo-for-agents.md`).
Removed text prints as its
category: `<path>`, `<n>`, `<str>` (quoted), `<var>`, `<url>`, `<word>`;
`-u<val>` means a value was glued to the flag; `<heredoc>`/`<loop>`/`<func>`
mark dropped structure. After `just`, a word survives only in recipe
position and only if the repo's recipe list (just's `--summary`) has it
(`just agent show`, `just preflight`); anything else is `<word>`. Every
token is checked against a closed vocabulary (see "Changing the miner");
`--json` for tooling. Four sections, four different verdicts:

- **SEQUENCES**: producers run one after another (`&&`/`;`), in >= 3
  sessions. The script candidates. Each row is already the longest run
  that holds its count; shorter overlapping rows are real sub-habits
  (e.g. `git branch -d -> git push --delete` alone, 43, versus the full
  post-merge cleanup starting at `git checkout`, 31).
- **BATCH READS**: one line, sessions reading several things per call and
  printing headers between them. At 2026-09-29: 82% and 87% of 73
  sessions, the commonest habit by far. Candidate for one reader script
  (N files/ranges, a header each), not for per-pair scripts.
- **PIPELINES**: filters per producer (`nix eval --raw | tail`,
  `grep -n | head`). Plain Unix; leave these alone unless the filter
  itself is a convention (a `jq` filter, a fixed `--json` field set).
- **JUST**: sessions per recipe called. `just` calls are kept out of
  SEQUENCES and PIPELINES (already scripts); this is where a helper's
  adoption shows. A helper still at 1-2 sessions weeks after it landed
  while its SEQUENCES row keeps growing is not being found: name it
  where agents look (the SessionStart hook lists the helper names).

## Worked examples (2026-09-29)

- `show`: the BATCH READS habit, as one reader over N specs.
- `preflight-brief`: `just preflight | grep | tail` to skim it; reads its
  steps from the preflight recipe so it can't drift.
- `commit`, `ship-ready`, `ship-land` (`ship.py`): skill `ship`'s
  commit conventions (pathspec, stdin message, trailer, no trunk
  commits), its step-2 preview and gate, and the post-merge cleanup
  (31 sessions) including the linked-worktree case.
- `pr` (`ship.py`, 2026-10-02): first left unscripted (`--body-file -`
  reads stdin), then wrapped once it carried conventions of its own: the
  disclosure line at both ends, `--base experimental`, push `-u` first.
- `worktree new/prune` (`worktree.py`), `preflight-each`: skill
  `use-a-worktree`'s create and its never-done cleanup, and ship's
  each-commit-green loop, which left worktrees behind when a check failed.
  2026-10-03: `preflight-brief` runs steps concurrently and
  `preflight-each` caches `just check` per `flake/` tree; for a larger
  range (several commits), at your judgement and memory permitting,
  `preflight-each --jobs N` runs N commits at once (clamped by
  `MemAvailable`; budget in its header).
- `where [<pr>]` (`where.py`, 2026-10-03): orientation, the largest
  unscripted habit left -- `git fetch -> git status -sb` (53 sessions),
  `git log --oneline <range> -> git diff --stat <range>` (50),
  `git log --oneline -N <-> git status -sb` (47), `gh pr view <n> --json
  -> log -> diff --stat` (30). Fetch (offline tolerated), status line,
  dirty paths, commits and diff stat against `origin/experimental`, the
  PR. Read-only.

Adoption, first JUST run (2026-10-03, nire-tenacity only: 68 Claude
Code + 49 zcode sessions; the other hosts' exports predate format 3 and
were skipped): `preflight` 69, `wiki-lint` 49, `agent preflight-brief`
5, `agent show`/`commit`/`pr`/`worktree`/`preflight-each`/`ship-ready`/
`ship-land` 1 each -- the helpers were days old, against 101 sessions
(86%) batch-reading by hand. Re-check once exports rebuild.

## Is it worth a script?

Yes when the pattern carries a **convention**: a header format, a set of
`nix eval`/`gh --json` flags, a fixed step order (fetch, then status).
No when it's plain Unix: a script hides what the user learns from reading
the command. Check `just agent` and the root `just` list first, and
**extend** an overlapping recipe rather than start a second one:
committing, ship's preview/gate and the post-merge cleanup are
`ship.py`'s; merged-elsewhere branches are `just branches prune`'s.

## Extract it

1. Script in `.agents/scripts/`, executable, any language. Generalize
   past the cases seen (N files, not two). The header says what question
   it answers and which SEQUENCES row or habit it replaces. A toolchain
   not already on the hosts (python3 and bash are; the flake has no
   devShells) → ask the user before adding a devShell.
2. One-line recipe in `.agents/scripts/agent.just`: summary comment, then
   `@"{{scripts}}/<script>" "$@"` (positional arguments are on, so quoted
   arguments stay whole). Module recipes run from `.agents/scripts/`, not
   the caller's directory: a script taking paths gets
   `cd "{{invocation_directory()}}" &&` first (`show` does); `{{repo}}` is
   the root.
3. Run it on a real case, and on one where it should find something and
   check it does: a script that reports success has not been tested (§1).
   Then commit it **on its own**, in the current branch/PR: `feat(agent-scripts): <name>`. No separate PR.
4. Skill `wiki-sync` covers naming it on its topic's wiki page. If a skill
   spells out the steps the script replaces (ship's preview, the cleanup),
   point that skill at the script.

## Changing the miner

The shape step in `recurring.py` is a privacy boundary: nothing literal
may survive into a shape. It works from allowlists (commands on PATH,
per-tool `SUBCOMMANDS`, `WRAPPERS`, `FIND_OPTS`); widening any of them
means adding a hostile case to `LEAKS` in `test_recurring.py` (runs in
`just preflight` and CI), which checks every shape token against the
closed vocabulary. It holds what leaked before: grep-pattern pieces as
fake commands (`git.moose"`), then value-glued flags (`-uadmin`), loop
variables (`for host in`), wrapper options (`sudo -u host`), prose from
quoted `--body "..."` text, `<<\EOF` heredoc bodies. Residual
(docstring): an unquoted 1-3 letter word after `-`, and unquoted
`--long-flag` names.

The `just` recipe vocabulary is read at run time (`just_recipes()`;
tests pin it): recipe names are repo-defined and public. A non-recipe
word after `just` stays `<word>`, and `test_recurring.py` holds cases
for that.

**Bump `FORMAT` whenever shaping gets stricter**, or the export's
shape changes (3: recipe names and the `just` kind). Exports merge, so keys
written under looser rules would otherwise persist; files of another
format are skipped on read and rebuilt on that host's next export.

Never commit transcript lines or raw commands: this repo is public, and
they carry hostnames, ports, and paths. The export is the only thing that
leaves a host; `test_recurring.py`'s `Export` case checks it against the
same vocabulary. Commands whose quoting shlex can't follow (escaped or
nested quotes) are dropped whole, about 4% at 2026-09-29: prose in
`gh ... --body "..."` leaked as commands before that.
