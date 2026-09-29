# 14. Read the repo's own conventions before writing into it

_Last modified: 2026-09-29_

§14 of [lessons-learned.md](../lessons-learned.md), the index that files every lesson by when it applies; this is §14's full account.

`manconfig.nix` was written with a 25-line header and rejected for not matching
its neighbours. The repo had a style guide all along, four levels down beside
the package modules with nothing linking to it. `grep -ri 'style\|convention'
--include='*.md'` costs nothing.
