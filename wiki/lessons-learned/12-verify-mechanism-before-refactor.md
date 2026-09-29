# 12. Verify the mechanism before betting a refactor on it

_Last modified: 2026-09-29_

§12 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §12's full account.

Before repairing `dirsAsCategory` rather than replacing it, the risky part —
reading `config.flake.modules.<class>` from a file that also *defines* an
attribute in it — was modelled with flake-parts' own option type and evaluated.
Cheap, and the difference between a recommendation and a guess.
