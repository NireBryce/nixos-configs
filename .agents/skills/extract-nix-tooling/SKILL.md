---
name: extract-nix-tooling
description: Records a Nix pattern or trap as an extraction candidate when it would work in any flake config.
when_to_use: Writing or changing a module, flake script, or Nix-related skill or lesson whose pattern isn't specific to this repo.
---

# Recording general Nix candidates, as you go

**Needs:** bash-guards

## Applies to

Use this when you write or change a flake-parts module, a `flake/scripts/` tool, a Nix-shaped skill, or an agent-lessons-learned § about Nix behavior, and the pattern would work in someone else's flake. Do not use it for:

- non-Nix agent tooling: `extract-agent-tooling`
- a deliberate whole-repo pass: `extract-nix-tooling-all`
- copying anything into another repo: never, unless the user asks for it

Candidates go in `_loose-ends/extraction-candidates/nix/`, one file per candidate, named `<short-name>.md`.

## Relationship to `extract-agent-tooling`

The rule (record, don't extract; the in-repo copy stays specific), the file shape and the steps are the same. Read that skill; they are not repeated here. Only the test and the folder differ.

## Precedent: two have already gone

The category machinery left this repo as the `dirs-as-categories` flake input (2026-10-16; `flake/doc/dirsAsCategory.md`'s header has the before, `wiki/config-structure/module-files.md` the after). The module-tree diagram left as `flake-module-graph`. Both are inputs in `flake/flake.nix`. Before recording a candidate, check whether it extends one of those instead of needing its own home, and say which in the file's "General kernel" line. The user decided each extraction; this skill only records.

## The Nix generality test

Strip this fleet's nouns (hostnames, `elly`, category names, sops paths, Tailscale, `just` recipes) but keep the Nix vocabulary. Then:

- **Works in any flake / NixOS / Home Manager / nix-darwin config**: candidate. `drop-unsupported-packages.nix` (platform gating off `meta.platforms`) and `lint.py`'s ratcheted statix+deadnix baseline are the shape.
- **Works only with this repo's layout** (a specific host's hardware, the impermanence subvolume names): not a candidate. The trap behind it may still be one: "the shell's mount namespace lies; read `/proc/1/mountinfo`" generalizes even though the subvolume names do not.
- **Works with no Nix at all**: use `extract-agent-tooling` instead.

A bug or missing feature in nixpkgs, Home Manager, or flake-parts belongs in `_loose-ends/bugs-pending-submission/`. This folder is for patterns this repo invented that others could reuse, not for fixes owed upstream.

**Evidence ranks candidates**, as in `extract-agent-tooling`: a pattern that `modules.py` or `lint.py` enforces, or that an agent-lessons-learned § records breaking, is stronger than one that is only tidy. Nix traps (`${…}` inside `''` strings, freeform settings swallowing misspelled keys, `git add` before `nix eval`) get most of their value from the evidence line.

## Steps

Follow `extract-agent-tooling`, writing to `_loose-ends/extraction-candidates/nix/`. Put the Nix-specific half of a split candidate here and the general half in the agent folder, each file linking the other.

## See also

- `extract-agent-tooling`: the rule, file shape, and steps.
- `extract-nix-tooling-all`: the sweep form.
- `new-flake-module`, `home-manager-dotfiles`: where most of the repo's Nix traps are already written down.
