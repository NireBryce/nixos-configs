# cod completion descriptions

_Last modified: 2026-09-27_

How [cod](carapace.md)'s completions get their descriptions in the ble.sh
menu — the one part cod cannot do for itself, bridged with a curated table
in this repo and a ble.sh advice hook. cod (the completion daemon,
[`cod-completions.nix`](../../../flake/modules/packages-config/shell-apps/completions/cod-completions.nix))
covers exactly the commands [carapace](carapace.md) doesn't: its config
ignores everything in carapace's spec list, and learns the rest at runtime
from `--help` output. Those commands (`sops`, `uv`, `tailscale`, `cod`
itself) are also precisely the ones with no man pages — so ble.sh's own
man-page (mandb) enrichment has nothing for them either, and before
2026-09-25 their menu candidates were bare words.

## Contents

- [Why cod can't do this itself](#why-cod-cant-do-this-itself)
- [The mechanism](#the-mechanism)
- [The table format](#the-table-format)
- [Extending it](#extending-it)
- [Traps](#traps)
- [See also](#see-also)

## Why cod can't do this itself

cod's completion protocol is plain bash: its completer `__cod_complete_bash`
fills `COMPREPLY` with one word per candidate, read from
`cod api complete-words`. And its database has no descriptions to serve even
if the protocol had a slot for them — the sqlite `Completion` table is
`(HelpPageId, Flag, Context)`, confirmed against dim-an/cod v0.1.0's source
and the live schema. Its own `--help` parser, which sees the very
description lines a human reads, throws them away. carapace had the same
bash-protocol gap but keeps real descriptions internally
(`carapace <cmd> export` re-derives them as JSON — see
[`carapace-desc.bash`](../../../flake/modules/general-config/shell-config/bash/carapace-desc.bash));
cod has no richer mode at all, so the descriptions are data this repo owns.

## The mechanism

Three pieces, all under
[`general-config/shell-config/bash/`](../../../flake/modules/general-config/shell-config/bash/):

1. **`cod-desc.tsv`** — the curated table: one
   `command<TAB>candidate<TAB>description` per line, `#` comments allowed,
   sorted. This is the only place the descriptions exist.
2. **`cod-desc.bash`** — a ble.sh `ble/function#advice after` hook on
   `__cod_complete_bash` (same pattern as `carapace-desc.bash`): let the
   real completer fill `COMPREPLY`, then re-yield each candidate through
   `ble/complete/cand/yield` with the table's description where one exists.
   Candidates with no row yield plain; a command with no rows at all leaves
   `COMPREPLY` untouched, so ble.sh's mandb enrichment and default handling
   still apply — an untabled command costs one hash lookup, nothing more.
   This is also why the table only covers cod's own domain and doesn't try
   to duplicate man pages.
3. **`blesh.nix`** — renders both files into the store (`pkgs.writeText`),
   points the advice at the table via the shell variable
   `NIRE_COD_DESC_TSV`, and imports the advice from `.blerc` with
   `ble-import -d`. The deferred import is load-bearing: `.blerc` is sourced
   before `bash.nix`'s later `initExtra` block runs `cod init`, so
   `__cod_complete_bash` doesn't exist yet at `.blerc` read time; by idle
   time it does.

ble.sh displays the descriptions because `.blerc` sets
`bleopt complete_menu_style=desc` (the same knob `carapace-desc.bash`
feeds).

## The table format

```
sops	--decrypt	Decrypt a file and output the result to stdout
sops	-d	Decrypt a file and output the result to stdout
```

- Three tab-separated fields; the description may contain tabs (the advice
  splits on the first two only).
- Candidates are keyed **without** a trailing `=`. cod serves `--opt=` for
  flags that take a value; the advice strips a trailing `=` and retries, so
  a row keyed with one could never match — `test_cod_desc.py` rejects it.
- Long and short spellings get separate rows (cod serves both).
- Sorted by command, then candidate; enforced.

## Extending it

The semi-automation, all through `just cod-desc`:

1. **Teach cod the command**: `cod learn -- <cmd> --help` — cod runs the
   command line it's given, parses the help text, and starts serving
   completions for it. Verify with `cod list` and
   `cod api complete-words -- $$ 2 <cmd> ''`. cod's help-execution timeout
   is **1 second**: slow-starting commands (`steamtinkerlaunch`,
   `opencode`) never learn, and there is nothing to configure about it.
2. **Draft rows**: `just cod-desc draft <cmd>...` runs `<cmd> --help`
   itself, parses flag and subcommand descriptions (kingpin and clap shapes
   are recognised; see `test_cod_desc.py` for what each looks like), and
   prints TSV lines for candidates cod actually serves, minus rows already
   in the table. Gaps print as `TODO` placeholders. **Drafts are a starting
   point** — review every line before adding it.
3. **Curate and commit** the rows into `cod-desc.tsv`.
4. **Check drift**: `just cod-desc audit` compares cod's learned commands
   with the table in both directions; `--used` adds the gap analysis
   against atuin history and carapace's spec list — the commands you run
   that nothing covers, i.e. the queue for step 1.

`just cod-desc-test` (in preflight and CI) pins the parsers with fixture
texts and checks the committed table and the blesh.nix wiring.

## Traps

- **cod's database stores the full environment of every learning shell**
  (`HelpPage.CommandJson`) — every variable in scope when `--help` ran. It
  is user-local state under `~/.local/share/cod/`, not a secret
  (`secrets-hygiene` doesn't apply), but don't paste `CommandJson` into
  chats or commits.
- **The learn step runs the command.** `cod learn -- <cmd> --help` executes
  `<cmd> --help`; only teach cod commands whose `--help` is safe to run,
  and the same caution applies to `just cod-desc draft`.
- **The ignore list is generated, not hand-kept.** carapace-covered
  commands are ignored via `~/.config/cod/config.toml`, regenerated at
  build time by `cod-completions.nix` — never add ignore rules by hand.
- **One owning module per generated file.** `blesh.nix` owns `.blerc`;
  wiring for a second completion source goes through it (as
  `cod-desc.bash` does), not through a second module declaring `.blerc`
  lines — `home.file.<n>.text` concatenates (the
  [shell-config](00-INDEX.md) concatenation trap).

## See also

- [carapace](carapace.md) — the primary completion engine, its `export`
  descriptions bridge, and the cod/carapace registration race.
- [blesh](blesh.md) — the `.blerc` this wiring lives in, and the menu that
  displays the descriptions.
- Skill `cod-completions` (`.agents/skills/cod-completions/SKILL.md`) —
  the workflow above as a runnable procedure.
