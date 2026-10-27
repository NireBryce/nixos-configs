# 12. Verify the mechanism before betting a refactor on it

_Last modified: 2026-09-29_

## Index entry

§12 in [agent-lessons-learned.md](../agent-lessons-learned.md), which keeps a one-line version of every lesson, filed by when it applies. This page is the longer write-up.

## The lesson

Before repairing `dirsAsCategory` rather than replacing it, the risky part —
reading `config.flake.modules.<class>` from a file that also *defines* an
attribute in it — was modelled with flake-parts' own option type and evaluated.
Cheap, and the difference between a recommendation and a guess.
