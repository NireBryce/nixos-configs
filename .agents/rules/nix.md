---
paths:
  - "**/*.nix"
---

# Writing Nix

## `${...}` inside a `''` string is interpolation

Writing `${terminfo[khome]}` in what you intend as a comment inside a `''`
string is an evaluation error. Escape it as `''${...}` or reword.

## An option that renders into a generated file can swallow a wrong key silently

Freeform settings options (typed `attrsOf …` with a `freeformType`, like
`security.pam.u2f.settings`) render any key verbatim into the generated
config: a misspelled or renamed key evals clean and the consumer discards
it. `settings.authFile` (camelCase of nixpkgs' `authfile`) was ignored by
pam_u2f for five months, masked by the value coinciding with the consumer's
default (§49 in `wiki/lessons-learned.md`). Eval passing is a claim about
the type, not the consumer: read the rendered artifact (`/etc/pam.d/<service>`
on the host, or eval `config.security.pam.services.<name>.text`) when a
change touches one.

Read the nixpkgs module's `mkRenamedOptionModule` block first; that is the
write-time half (§33). The same read shows the defaults, and config that
restates one reads as a decision nobody made, so leave it out.
