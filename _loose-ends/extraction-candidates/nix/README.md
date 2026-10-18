# Extraction candidates — general Nix

One file per thing in this repo that would serve any Nix flake / NixOS /
Home Manager / nix-darwin config, not just this fleet — module patterns,
flake-parts machinery, lint and diff scripts, Nix-specific traps and the
skills that guard them — recorded for a future general Nix repo. No such
repo exists yet; nothing here gets copied anywhere without the user asking
(AGENTS.md, "Never file anything outside").

Maintained by skills `extract-nix-tooling` (one candidate, as you go) and
`extract-nix-tooling-all` (whole-repo sweep). Entry shape comes from
`extract-agent-tooling`; non-Nix agent tooling goes in
`../agent-orchestration/` instead.

Candidates are the other `*.md` files here, one per candidate, named
`<short-name>.md` (kebab-case).
