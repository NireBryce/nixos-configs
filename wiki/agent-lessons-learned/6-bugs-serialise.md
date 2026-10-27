# 6. Bugs serialise

_Last modified: 2026-09-29_

## Index entry

§6 in [agent-lessons-learned.md](../agent-lessons-learned.md), which keeps a one-line version of every lesson, filed by when it applies. This page is the longer write-up.

## The lesson

`SESSION-HANDOFF.md` §3 said four bugs had hidden behind one another on the
sibling branch. Four more did here, each invisible until the one before it
landed: `.blerc` declared twice → `boot` both a category and a module →
`jq`/`bitwarden` declaring nixos modules full of `home.packages` →
`programs.bash.blesh.enable`, an option Home Manager has never had.

**A defect count from static analysis is a lower bound.** The plan said eight;
it was twelve.
