# Extraction candidates — general agent orchestration

One file per thing in this repo whose mechanism would work in *any* repo an
agent works in — skills, wiki conventions, lessons, hooks, lint scripts,
AGENTS.md structure — recorded for a future general-purpose repo. No such
repo exists yet; nothing here gets copied anywhere without the user asking
(AGENTS.md, "Never file anything outside").

Maintained by skills `extract-agent-tooling` (one candidate, as you go) and
`extract-agent-tooling-all` (whole-repo sweep). Entry shape and the
generality test live in `extract-agent-tooling`; Nix-specific candidates go
in `../nix/` instead.

Candidates are the other `*.md` files here, one per candidate, named
`<short-name>.md` (kebab-case).
