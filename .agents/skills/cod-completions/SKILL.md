---
name: cod-completions
description: How to give cod's completions their ble.sh menu descriptions and keep the curated table behind them current.
---

# cod completion descriptions

## Applies to

| Trigger | Use this |
| --- | --- |
| "candidates for `<cmd>` show no descriptions in the ble.sh menu" | Audit (below), then the extend procedure |
| adding a new command to cod's coverage | Extend, steps 1–3 |
| changing `cod-desc.tsv`, `cod-desc.bash`, or the cod wiring in `blesh.nix` | `just cod-desc-test` before landing |
| carapace-covered commands missing descriptions | Not this — that is `carapace-desc.bash`; start from `blesh.md` |
| editing `.blerc` itself | skill `home-manager-dotfiles` — `blesh.nix` owns the file |

## Quick start

```sh
just cod-desc audit --used        # what's uncovered right now
cod learn -- <cmd> --help         # teach cod the command
just cod-desc draft <cmd>         # draft TSV rows parsed from --help
just cod-desc-test                # fixture tests + committed-table check
```

Background (why cod can't carry descriptions, advice mechanism, table format):
[wiki/categories/shell-config/cod-desc.md](../../../wiki/categories/shell-config/cod-desc.md). This skill is the procedure.

## The pieces, and which to touch

| File | Role |
| --- | --- |
| `flake/modules/general-config/shell-config/bash/cod-desc.tsv` | the descriptions (curated data — the only place they exist) |
| `flake/modules/general-config/shell-config/bash/cod-desc.bash` | ble.sh `after`-advice on cod's `__cod_complete_bash`; reads the table via `NIRE_COD_DESC_TSV` |
| `flake/modules/general-config/shell-config/bash/blesh.nix` | renders both into the store and imports the advice from `.blerc` |
| `flake/scripts/cod-desc.py` | `draft` / `audit` / `check`; `just cod-desc` dispatches to it |

## Extending coverage

1. **Teach cod first**: `cod learn -- <cmd> --help`. This *executes* the
   command line — only name commands whose `--help` is safe to run. cod's
   help-execution timeout is 1 second; slow-starting commands never learn
   and there is no knob. Verify with `cod list` and
   `cod api complete-words -- $$ 2 <cmd> ''`.
2. **Draft**: `just cod-desc draft <cmd>` parses the `--help` text
   (kingpin and clap shapes; anything else drafts `TODO` placeholders) and
   prints rows for the candidates cod actually serves, skipping rows the
   table already has.
3. **Curate**: drafts are not authoritative — fix wording, drop flags not
   worth describing, keep candidates keyed *without* a trailing `=`, keep
   the file sorted. Then `just cod-desc-test`.
4. **Learned state is per-host, per-user** (`~/.local/share/cod/`): step 1
   is repeatable runtime state, not config. The table is what ships to
   every host; on a new host the rows stay dormant until cod learns the
   command there.

## Verification limits

Verified 2026-09-25 by driving the real `__cod_complete_bash` (daemon and all) under a real ble.sh with only the candidate-yield layer stubbed to a log: descriptions attached, trailing-`=` resolved via the stripped key, unknown commands untouched. Not covered: the menu painting the desc column under a live attach. If descriptions don't show, check `complete -p <cmd>` really names
`__cod_complete_bash` (cod registers per learned command only), that
`NIRE_COD_DESC_TSV` is set in the shell (plain variable, set by `.blerc`),
and that the command has rows in `cod-desc.tsv` — everything else falls
back silently by design.

## See also

- Skill `keybinding-cheatsheet` — the same generate/test/wire shape for
  keybindings, including the regex-coupling rationale for the wiring tests.
- Skill `home-manager-dotfiles` — why `.blerc` lines go through `blesh.nix`
  and nothing else.
