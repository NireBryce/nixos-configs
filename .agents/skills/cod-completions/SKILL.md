---
name: cod-completions
description: Adds ble.sh menu descriptions to cod's completions and keeps the curated description table current.
when_to_use: Candidates for a command show no descriptions in the ble.sh menu, adding a command to cod's coverage, or changing the cod-desc table.
---

# cod completion descriptions

## Applies to

| Trigger | Use this |
| --- | --- |
| "candidates for `<cmd>` show no descriptions in the ble.sh menu" | Audit (below), then the extend procedure |
| adding a new command to cod's coverage | Extend, steps 1–3 |
| changing `cod-desc.tsv`, `cod-desc.bash`, or the cod wiring in `blesh.nix` | `just cod-desc-test` before landing |
| carapace-covered commands missing descriptions | Not this skill. That is `carapace-desc.bash`; start from `blesh.md` |
| editing `.blerc` itself | skill `home-manager-dotfiles`; `blesh.nix` owns the file |

## Quick start

```sh
just cod-desc audit --used        # what's uncovered right now
cod learn -- <cmd> --help         # teach cod the command
just cod-desc draft <cmd>         # draft TSV rows parsed from --help
just cod-desc-test                # fixture tests + committed-table check
```

Background (why cod cannot carry descriptions, the advice mechanism, the table
format):
[wiki/config-structure/categories/shell-config/cod-desc.md](../../../wiki/config-structure/categories/shell-config/cod-desc.md).
This skill is the procedure.

## The pieces, and which to touch

| File | Role |
| --- | --- |
| `flake/modules/general-config/shell-config/bash/cod-desc.tsv` | the descriptions (curated data; the only place they exist) |
| `flake/modules/general-config/shell-config/bash/cod-desc.bash` | ble.sh `after`-advice on cod's `__cod_complete_bash`; reads the table via `NIRE_COD_DESC_TSV` |
| `flake/modules/general-config/shell-config/bash/blesh.nix` | renders both into the store and imports the advice from `.blerc` |
| `flake/scripts/cod-desc.py` | `draft` / `audit` / `check`; `just cod-desc` dispatches to it |

## Extending coverage

1. **Teach cod first**: `cod learn -- <cmd> --help`. This *executes* the
   command line, so only name commands whose `--help` is safe to run. cod's
   help-execution timeout is 1 second and has no setting; a slow-starting
   command never learns. Verify with `cod list` and
   `cod api complete-words -- $$ 2 <cmd> ''`.
2. **Draft**: `just cod-desc draft <cmd>` parses the `--help` text (kingpin
   and clap shapes; any other shape drafts `TODO` placeholders) and prints
   rows for the candidates cod serves, skipping rows the table already has.
3. **Curate**: drafts need editing. Fix the wording, drop flags not worth
   describing, key candidates *without* a trailing `=`, and keep the file
   sorted. Then run `just cod-desc-test`.
4. **Learned state is per-host and per-user** (`~/.local/share/cod/`), so
   step 1 is repeatable runtime state, not config. The table ships to every
   host; on a new host its rows stay dormant until cod learns the command
   there.

## Live check

`just completion-live-test` presses real Tab in an attached ble.sh (via
terminal-puppeteer) for the read-fix, carapace's descriptions and cod's
descriptions, using this working tree's files. It is opt-in, takes about 30
seconds, and is not in preflight. Each missing prerequisite skips with its
fix (the cod case needs `sops` learned in cod). Run it after editing
`cod-desc.bash`, `cod-desc.tsv`, `carapace-desc.bash` or the read-fix.

A check with ble.sh's functions stubbed tests your model of ble.sh, not
ble.sh. The stubbed checks (including `test_cod_desc.py`'s) passed three bugs
that this one catches, so for these files only a real Tab press counts as
*runs* (agent-lessons-learned §50). How it differs from the real shell, and
how to point it at older files: the header of
`flake/scripts/tests/test_completion_live.py`.

## Verification limits

- 2026-09-25: drove the real `__cod_complete_bash` (daemon and all) under a
  real ble.sh with only the candidate-yield layer stubbed to a log.
  Descriptions attached, trailing-`=` resolved via the stripped key, unknown
  commands untouched.
- 2026-10-26: verified live with `terminal-puppeteer --cmd 'bash -i'` (Tab Tab
  after `sops --de`); the menu shows the descriptions. Only this run caught
  `cod-desc.bash`'s cache being function-local when loaded by `ble-import`.
  The command must be cod-owned: `complete -p <cmd>` names
  `__cod_complete_bash` (`uv` is carapace's here).

If descriptions do not show, check three things. `complete -p <cmd>` must name
`__cod_complete_bash` (cod registers per learned command only).
`NIRE_COD_DESC_TSV` must be set in the shell (a plain variable, set by
`.blerc`). The command must have rows in `cod-desc.tsv`. Any other failure
falls back silently by design.

## See also

- Skill `keybinding-cheatsheet`: the same generate/test/wire shape for
  keybindings, including the regex-coupling rationale for the wiring tests.
- Skill `home-manager-dotfiles`: why `.blerc` lines go through `blesh.nix` and
  nothing else.
