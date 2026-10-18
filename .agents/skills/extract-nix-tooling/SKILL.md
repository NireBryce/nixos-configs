---
name: extract-nix-tooling
description: How to notice, while editing a module, script, or skill, that a Nix pattern or trap would serve any flake config, and record it as an extraction candidate.
when_to_use: Writing or changing a module, flake script, or Nix-shaped skill or lesson whose pattern would work in any flake.
---

# Recording general Nix candidates, as you go

## Applies to

You are writing or changing a flake-parts module, a `flake/scripts/` tool, a Nix-shaped skill, or a lessons-learned
§ about Nix behavior, and notice the pattern would work in someone else's
flake. Not: non-Nix agent tooling (`extract-agent-tooling`); a deliberate
whole-repo pass (`extract-nix-tooling-all`); copying anything into another
repo (never, unless the user asks in those words).

Candidates go in `_loose-ends/extraction-candidates/nix/`, one file per
candidate, named `<short-name>.md`.

## Relationship to `extract-agent-tooling`

Same rule (record, don't extract; the in-repo copy stays specific), same
file shape, same steps — read that skill; they aren't repeated here. Only
the test and the folder differ.

## Precedent: two have already gone

The category machinery left this repo as the `dirs-as-categories` flake
input (2026-10-16; `flake/doc/dirsAsCategory.md`'s header has the before,
`wiki/module-files.md` the after), and the module-tree diagram as
`flake-module-graph`. Both are inputs in `flake/flake.nix`. So before
recording a candidate, ask whether it extends one of those rather than
needing a home of its own; say which in the file's "General kernel" line.
The extraction itself was the user's call each time — this skill still only
records.

## The Nix generality test

Strip this fleet's nouns — hostnames, `elly`, category names, sops paths,
Tailscale, `just` recipes — but keep the Nix vocabulary. Then:

- **Works in any flake / NixOS / Home Manager / nix-darwin config** →
  candidate. `drop-unsupported-packages.nix` (platform gating off
  `meta.platforms`) and `lint.py`'s ratcheted statix+deadnix baseline
  are the shape.
- **Works only with this repo's layout** (a specific host's hardware,
  the impermanence subvolume names) → not a candidate. The *trap* behind
  it may still be: "the shell's mount namespace lies; read
  `/proc/1/mountinfo`" generalizes even though the subvolume names don't.
- **Works with no Nix at all** → `extract-agent-tooling` instead.

Upstream-shaped findings are a separate thing. A bug or missing feature in
nixpkgs, Home Manager, or flake-parts belongs in
`_loose-ends/bugs-pending-submission/`, not this folder — the folder is
for patterns *this repo* invented that others could reuse, not fixes owed
upstream.

**Evidence** matters the same way: a pattern that `modules.py` or
`lint.py` enforces, or that a lessons-learned § records breaking, is a
stronger candidate than one that's just tidy. Nix traps (`${…}` inside
`''` strings, freeform settings swallowing misspelled keys, `git add`
before `nix eval`) carry most of their value in the evidence line.

## Steps

As in `extract-agent-tooling`, writing to `_loose-ends/extraction-candidates/nix/`.
Put the Nix-specific half of a split candidate here and the general half
in the agent folder, each file linking the other.

## See also

- `extract-agent-tooling` — the rule, file shape, and steps.
- `extract-nix-tooling-all` — the sweep form.
- `new-flake-module`, `home-manager-dotfiles` — where most of the
  repo's Nix traps are written down already.
