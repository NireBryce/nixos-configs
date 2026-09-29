# 6. Bugs serialise

_Last modified: 2026-09-29_

§6 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §6's full account.

`SESSION-HANDOFF.md` §3 said four bugs had hidden behind one another on the
sibling branch. Four more did here, each invisible until the one before it
landed: `.blerc` declared twice → `boot` both a category and a module →
`jq`/`bitwarden` declaring nixos modules full of `home.packages` →
`programs.bash.blesh.enable`, an option Home Manager has never had.

**A defect count from static analysis is a lower bound.** The plan said eight;
it was twelve.
